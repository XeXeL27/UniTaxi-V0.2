package com.taxiuap.backend.communication.service;

import java.util.List;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.communication.dto.ContactoEmergenciaRequest;
import com.taxiuap.backend.communication.dto.ContactoEmergenciaResponse;
import com.taxiuap.backend.communication.entity.ContactoEmergencia;
import com.taxiuap.backend.communication.repository.ContactoEmergenciaRepository;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.repository.UsuarioRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;

import lombok.RequiredArgsConstructor;

/** CRUD de los contactos de emergencia del usuario autenticado, con borrado logico. */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class ContactoEmergenciaService {

    private final ContactoEmergenciaRepository contactoEmergenciaRepository;
    private final UsuarioRepository usuarioRepository;

    public List<ContactoEmergenciaResponse> listar(Long idUsuario) {
        return contactoEmergenciaRepository.findByUsuarioId(idUsuario).stream()
                .filter(contacto -> contacto.getEstadoContEmerg() == EstadoRegistro.A)
                .map(this::aRespuesta)
                .toList();
    }

    @Transactional
    public ContactoEmergenciaResponse crear(Long idUsuario, ContactoEmergenciaRequest request) {
        ContactoEmergencia contacto = new ContactoEmergencia();
        contacto.setUsuario(buscarUsuario(idUsuario));
        contacto.setNombre(request.nombre());
        contacto.setTelefono(request.telefono());
        contacto.setParentesco(request.parentesco());
        contacto.setEstadoContEmerg(EstadoRegistro.A);

        return aRespuesta(contactoEmergenciaRepository.save(contacto));
    }

    @Transactional
    public ContactoEmergenciaResponse actualizar(Long idUsuario, Long id, ContactoEmergenciaRequest request) {
        ContactoEmergencia contacto = buscarDelUsuario(id, idUsuario);

        contacto.setNombre(request.nombre());
        contacto.setTelefono(request.telefono());
        contacto.setParentesco(request.parentesco());

        return aRespuesta(contactoEmergenciaRepository.save(contacto));
    }

    @Transactional
    public void eliminar(Long idUsuario, Long id) {
        ContactoEmergencia contacto = buscarDelUsuario(id, idUsuario);
        contacto.setEstadoContEmerg(EstadoRegistro.X);
        contactoEmergenciaRepository.save(contacto);
    }

    private Usuario buscarUsuario(Long idUsuario) {
        return usuarioRepository.findById(idUsuario)
                .orElseThrow(() -> RecursoNoEncontradoException.de("Usuario", idUsuario));
    }

    private ContactoEmergencia buscarDelUsuario(Long id, Long idUsuario) {
        ContactoEmergencia contacto = contactoEmergenciaRepository.findById(id)
                .orElseThrow(() -> RecursoNoEncontradoException.de("ContactoEmergencia", id));
        if (contacto.getUsuario() == null || !contacto.getUsuario().getId().equals(idUsuario)) {
            throw RecursoNoEncontradoException.de("ContactoEmergencia", id);
        }
        return contacto;
    }

    private ContactoEmergenciaResponse aRespuesta(ContactoEmergencia contacto) {
        return new ContactoEmergenciaResponse(
                contacto.getId(),
                contacto.getNombre(),
                contacto.getTelefono(),
                contacto.getParentesco());
    }
}
