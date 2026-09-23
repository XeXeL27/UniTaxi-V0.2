package com.taxiuap.backend.controller.admin;

import java.util.List;
import java.util.Map;

import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import com.taxiuap.backend.config.security.UsuarioActual;
import com.taxiuap.backend.identity.dto.HabilitarUsuarioRequest;
import com.taxiuap.backend.identity.dto.PersonaAdminResponse;
import com.taxiuap.backend.identity.dto.PersonaRequest;
import com.taxiuap.backend.identity.dto.UsuarioAdminResponse;
import com.taxiuap.backend.identity.service.GestionPersonaService;
import com.taxiuap.backend.identity.service.GestionUsuarioService;
import com.taxiuap.backend.shared.response.ApiResponse;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/** Registro, edicion y borrado logico de personas, y alta de sus cuentas de usuario. */
@RestController
@RequestMapping("/api/admin/personas")
@RequiredArgsConstructor
public class PersonaAdminController {

    private final GestionPersonaService gestionPersonaService;
    private final GestionUsuarioService gestionUsuarioService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<PersonaAdminResponse>>> listar() {
        return ResponseEntity.ok(ApiResponse.exito(gestionPersonaService.listar()));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<PersonaAdminResponse>> obtener(@PathVariable Long id) {
        return ResponseEntity.ok(ApiResponse.exito(gestionPersonaService.obtener(id)));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<PersonaAdminResponse>> crear(@Valid @RequestBody PersonaRequest datos) {
        PersonaAdminResponse creada = gestionPersonaService.crear(datos);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.exito("Persona registrada", creada));
    }

    @PutMapping("/{id}")
    public ResponseEntity<ApiResponse<PersonaAdminResponse>> actualizar(
            @PathVariable Long id, @Valid @RequestBody PersonaRequest datos) {
        PersonaAdminResponse actualizada = gestionPersonaService.actualizar(id, datos);
        return ResponseEntity.ok(ApiResponse.exito("Persona actualizada", actualizada));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> eliminar(@PathVariable Long id) {
        gestionPersonaService.eliminar(id, UsuarioActual.idUsuario());
        return ResponseEntity.ok(ApiResponse.exito("Persona eliminada", null));
    }

    /**
     * Habilita cuentas para la persona. Es multipart: la parte "datos" (JSON) lleva el tipo y las
     * credenciales, y cada PDF va en una parte cuyo nombre es el tipo de documento (CI, LICENCIA...).
     */
    @PostMapping(value = "/{id}/usuarios", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<ApiResponse<List<UsuarioAdminResponse>>> habilitarUsuario(
            @PathVariable Long id,
            @Valid @RequestPart("datos") HabilitarUsuarioRequest datos,
            @RequestParam Map<String, MultipartFile> archivos) {
        List<UsuarioAdminResponse> creados = gestionUsuarioService.habilitar(id, datos, archivos);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.exito("Usuario habilitado", creados));
    }
}
