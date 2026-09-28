package com.taxiuap.backend.identity.service;

import java.io.IOException;

import org.springframework.core.io.Resource;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.repository.UsuarioRepository;
import com.taxiuap.backend.shared.archivo.AlmacenamientoArchivos;
import com.taxiuap.backend.shared.archivo.ProcesadorImagen;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;

import lombok.RequiredArgsConstructor;

/**
 * Foto de perfil de una cuenta (pasajero o conductor). Se recorta al cuadrado y se guarda en la
 * carpeta general de la persona como foto_perfil_&lt;rol&gt;.jpg; usuario.foto_url guarda esa ruta.
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class FotoPerfilService {

    private final UsuarioRepository usuarioRepository;
    private final AlmacenamientoArchivos almacenamientoArchivos;

    @Transactional
    public String subir(Long idUsuario, MultipartFile archivo) {
        if (archivo == null || archivo.isEmpty()) {
            throw new NegocioException("Elija una foto");
        }
        if (archivo.getSize() > AlmacenamientoArchivos.TAMANO_MAXIMO_IMAGEN) {
            throw new NegocioException("La foto supera los 5 MB");
        }
        byte[] procesada;
        try {
            procesada = ProcesadorImagen.fotoPerfil(archivo.getBytes());
        } catch (IOException e) {
            throw new NegocioException("No se pudo leer la foto");
        }
        Usuario usuario = buscar(idUsuario);
        String ruta = almacenamientoArchivos.carpetaGeneral(usuario.getPersona())
                + "/foto_perfil_" + usuario.getRol().getCodigo().toLowerCase() + ".jpg";
        almacenamientoArchivos.guardar(procesada, ruta);
        usuario.setFotoUrl(ruta);
        return ruta;
    }

    public Resource leer(Long idUsuario) {
        Usuario usuario = buscar(idUsuario);
        if (usuario.getFotoUrl() == null || !almacenamientoArchivos.existe(usuario.getFotoUrl())) {
            throw new RecursoNoEncontradoException("La cuenta no tiene foto de perfil");
        }
        return almacenamientoArchivos.leer(usuario.getFotoUrl());
    }

    private Usuario buscar(Long idUsuario) {
        return usuarioRepository.findById(idUsuario)
                .orElseThrow(() -> RecursoNoEncontradoException.de("Usuario", idUsuario));
    }
}
