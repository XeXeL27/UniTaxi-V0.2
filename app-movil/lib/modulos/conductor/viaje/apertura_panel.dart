/// Si el panel del viaje del repartidor se abre solo.
///
/// Antes se abria en cada cambio de etapa, sin exception: el repartidor iba a drovear con el panel
/// encima del mapa y lo cerraba, y a los pocos segundos se le volvia a abrir solo. Ahora se abre la
/// primera vez de cada viaje y, si el repartidor lo baja, se respeta su decision hasta que vuelva a
/// abrirlo o termine el viaje.
class AperturaPanelConductor {
  bool abierto = true;
  bool _plegadoPorEl = false;
  bool _primeraEtapa = true;

  /// Hubo un cambio de etapa. Devuelve si el panel debe quedar abierto.
  bool cambioDeEtapa() {
    if (_primeraEtapa) {
      _primeraEtapa = false;
      return abierto = true;
    }
    return abierto = !_plegadoPorEl;
  }

  /// El repartidor toco la barra del panel.
  void alternar() {
    abierto = !abierto;
    _plegadoPorEl = !abierto;
  }

  /// Empieza otro viaje: el panel se abre otra vez y se olvida la decision anterior.
  void nuevoViaje() {
    abierto = true;
    _plegadoPorEl = false;
    _primeraEtapa = true;
  }
}