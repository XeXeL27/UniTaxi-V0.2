import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/relieve.dart';
import '../../core/tema.dart';
import '../../widgets/campos_ficha.dart';
import '../../widgets/insignia_estado.dart';
import '../../widgets/modal_formulario.dart';
import 'formulario_habilitar_usuario.dart';
import 'modelos.dart';
import 'personas_api.dart';

/// Edicion de los tipos de usuario de una persona (PASAJERO, CONDUCTOR de taxi, DELIVERY, ADMIN), la
/// usan la ficha del usuario y la de la persona. Se marcan uno o mas; conductor de taxi y delivery no van
/// juntos. Quitar, pasar de taxi a delivery (o al reves) y agregar pasajero se guardan con
/// PUT /api/admin/personas/{id}/tipos; agregar conductor, delivery o administrador (piden licencia, moto,
/// cargo o credenciales) abre Habilitar usuario con la persona y esos tipos marcados.
class EdicionTipos {
  final PersonasApi api;

  /// Cuanto puede adelantar en una compra; se pide al pasar de taxi a delivery.
  final limite = TextEditingController();

  int _idPersona = 0;
  Set<String> _guardados = {};
  String _limiteGuardado = '';
  Set<String> elegidos = {};

  EdicionTipos(this.api);

  /// Pone los tipos guardados (al cargar la ficha, al descartar y despues de guardar).
  void cargar(int idPersona, List<String> tipos, num? limiteAdelanto) {
    _idPersona = idPersona;
    _guardados = tipos.toSet();
    elegidos = tipos.toSet();
    _limiteGuardado = limiteAdelanto?.toString() ?? '';
    limite.text = _limiteGuardado;
  }

  /// Vuelve a lo guardado (Cancelar en la ficha).
  void descartar() {
    elegidos = {..._guardados};
    limite.text = _limiteGuardado;
  }

  void dispose() => limite.dispose();

  List<String> get guardados => [
    for (final t in TipoRegistro.values)
      if (_guardados.contains(t.codigo)) t.codigo,
  ];

  bool get cambio => !setEquals(elegidos, _guardados);

  bool get pasaADelivery => elegidos.contains('DELIVERY') && _guardados.contains('CONDUCTOR');

  bool get pasaATaxi => elegidos.contains('CONDUCTOR') && _guardados.contains('DELIVERY');

  /// Tipos elegidos que piden datos y se agregan con el formulario Habilitar usuario.
  Set<String> get conFormulario {
    final conductor = _guardados.contains('CONDUCTOR') || _guardados.contains('DELIVERY');
    return {
      for (final tipo in elegidos)
        if (switch (tipo) {
          // Pasajero sin otra cuenta de la app: hacen falta su usuario y contrasena.
          'PASAJERO' => !_guardados.contains('PASAJERO') && !_guardados.any((t) => t != 'ADMIN'),
          'CONDUCTOR' || 'DELIVERY' => !conductor,
          _ => !_guardados.contains(tipo),
        })
          tipo,
    };
  }

  /// Marca o desmarca un tipo. Devuelve un error para mostrar si no se puede.
  String? alternar(String tipo) {
    if (elegidos.contains(tipo)) {
      if (elegidos.length == 1 && _guardados.isNotEmpty) {
        return 'Deje al menos un tipo de usuario. Para quitarle todos use Eliminar';
      }
      elegidos = {...elegidos}..remove(tipo);
      return null;
    }
    // Una sola cuenta de conductor: taxi o delivery.
    elegidos = {
      ...elegidos.where((t) => !(tipo == 'CONDUCTOR' && t == 'DELIVERY' || tipo == 'DELIVERY' && t == 'CONDUCTOR')),
      tipo,
    };
    return null;
  }

  /// La cuenta con este rol deja de existir con los tipos elegidos.
  bool quitaCuenta(String rol) => switch (rol) {
    'PASAJERO' => !elegidos.contains('PASAJERO'),
    'CONDUCTOR' => !elegidos.contains('CONDUCTOR') && !elegidos.contains('DELIVERY'),
    'ADMIN' => !elegidos.contains('ADMIN'),
    _ => false,
  };

  static String nombre(String codigo) =>
      TipoRegistro.values.where((t) => t.codigo == codigo).firstOrNull?.etiqueta ?? nombreTipoUsuario(codigo);

  static String lista(Iterable<String> tipos) {
    final nombres = [for (final t in tipos) nombre(t).toLowerCase()];
    if (nombres.length < 2) return nombres.join();
    return '${nombres.sublist(0, nombres.length - 1).join(', ')} y ${nombres.last}';
  }

  bool _esCambioDeServicio(String quitado, Set<String> otros) =>
      quitado == 'CONDUCTOR' && otros.contains('DELIVERY') || quitado == 'DELIVERY' && otros.contains('CONDUCTOR');

  /// Lo que se le avisa al confirmar.
  List<String> avisos() {
    if (!cambio) return const [];
    final formulario = conFormulario;
    final quitados = _guardados.difference(elegidos).where((t) => !_esCambioDeServicio(t, elegidos));
    final agregados = elegidos
        .difference(_guardados)
        .difference(formulario)
        .where((t) => !_esCambioDeServicio(t, _guardados));
    return [
      if (quitados.isNotEmpty) 'Se quitará ${lista(quitados)}.',
      if (agregados.isNotEmpty) 'Se agregará ${lista(agregados)}.',
      if (pasaADelivery) 'Su moto pasará a delivery: solo verá entregas.',
      if (pasaATaxi) 'Su moto pasará a taxi: solo verá viajes.',
      if (formulario.isNotEmpty)
        'Para agregar ${lista(formulario)} se abrirá Habilitar usuario para completar sus datos.',
      if (_guardados.any((t) => t != 'ADMIN'))
        'Si tiene la sesión abierta en la app, se cerrará y al ingresar elegirá con qué cuenta entrar.',
    ];
  }

  /// Guarda el cambio de tipos. Devuelve una nota para el aviso final (o null).
  Future<String?> guardar(BuildContext context) async {
    final formulario = conFormulario;
    final directos = elegidos.difference(formulario);
    final valor = num.tryParse(limite.text.trim().replaceAll(',', '.'));
    final limiteSiAplica = pasaADelivery ? valor : null;
    if (directos.isNotEmpty && !setEquals(directos, _guardados)) {
      await api.cambiarTipos(_idPersona, directos.toList(), limiteAdelantoCompra: limiteSiAplica);
    }
    if (formulario.isEmpty || !context.mounted) return null;

    final persona = await api.persona(_idPersona);
    if (!context.mounted) return null;
    final resultado = await abrirModal(
      context,
      FormularioHabilitarUsuario(
        api: api,
        persona: persona,
        tiposIniciales: [
          for (final t in TipoRegistro.values)
            if (formulario.contains(t.codigo)) t,
        ],
      ),
    );
    if (resultado is! UsuarioHabilitado) {
      return 'No se agregó ${lista(formulario)} porque se canceló Habilitar usuario.';
    }
    // Si todo lo elegido pedia datos, lo que habia que quitar se quita recien ahora.
    if (directos.isEmpty && _guardados.isNotEmpty) {
      await api.cambiarTipos(_idPersona, elegidos.toList(), limiteAdelantoCompra: limiteSiAplica);
    }
    return resultado.mensaje;
  }
}

/// Campo "Tipos de usuario": insignias en la vista y chips (uno o mas) al editar. Ocupa todo el ancho.
class CampoTiposUsuario extends StatelessWidget {
  final EdicionTipos tipos;
  final bool editando;

  /// Se llama al marcar o desmarcar (para redibujar la ficha).
  final VoidCallback alCambiar;

  /// Error al desmarcar el ultimo tipo.
  final ValueChanged<String> alError;

  const CampoTiposUsuario({
    super.key,
    required this.tipos,
    required this.editando,
    required this.alCambiar,
    required this.alError,
  });

  @override
  Widget build(BuildContext context) {
    final guardados = tipos.guardados;
    if (!editando) {
      return DatoFicha.widget(
        'Tipos de usuario',
        contenido: guardados.isEmpty
            ? const Text('Sin usuario', style: TextStyle(color: Relieve.tenue))
            : Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [for (final t in guardados) InsigniaEstado(t, texto: EdicionTipos.nombre(t))],
              ),
      );
    }
    final formulario = tipos.conFormulario;
    return DatoFicha.widget(
      'Tipos de usuario',
      contenido: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tipo in TipoRegistro.values)
                FilterChip(
                  selected: tipos.elegidos.contains(tipo.codigo),
                  onSelected: (_) {
                    final error = tipos.alternar(tipo.codigo);
                    if (error != null) {
                      alError(error);
                    } else {
                      alCambiar();
                    }
                  },
                  avatar: Icon(
                    tipo.icono,
                    size: 14,
                    color: tipos.elegidos.contains(tipo.codigo) ? Colors.white : ColoresApp.azul,
                  ),
                  label: Text(tipo.etiqueta),
                  showCheckmark: false,
                  selectedColor: ColoresApp.azul,
                  labelStyle: TextStyle(color: tipos.elegidos.contains(tipo.codigo) ? Colors.white : ColoresApp.azul),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            [
              'Marque uno o más. Conductor de taxi y delivery no van juntos.',
              if (formulario.isNotEmpty)
                'Para agregar ${EdicionTipos.lista(formulario)} al guardar se abrirá Habilitar usuario para completar sus datos.',
              if (tipos.cambio && guardados.any((t) => t != 'ADMIN')) 'Se cerrará su sesión en la app.',
            ].join(' '),
            style: const TextStyle(fontSize: 12, color: Relieve.tenue, height: 1.35),
          ),
        ],
      ),
    );
  }
}

/// "Limite para adelantar compras", solo al editar y al pasar de taxi a delivery.
class CampoLimiteAdelanto extends StatelessWidget {
  final EdicionTipos tipos;

  const CampoLimiteAdelanto({super.key, required this.tipos});

  @override
  Widget build(BuildContext context) {
    return CampoTextoFicha(
      etiqueta: 'Límite para adelantar compras (Bs)',
      controlador: tipos.limite,
      editando: true,
      largoMaximo: 9,
      teclado: const TextInputType.numberWithOptions(decimal: true),
      formatos: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      ayuda: 'Cuánto puede pagar de su bolsillo en un pedido de compra. Vacío = el que tenía',
      validar: (v) {
        final texto = v?.trim() ?? '';
        if (texto.isEmpty) return null;
        final valor = num.tryParse(texto.replaceAll(',', '.'));
        return valor == null || valor < 0 || valor > 100000 ? 'Monto no válido' : null;
      },
    );
  }
}
