package com.taxiuap.backend.controller.pasajero;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.config.security.UsuarioActual;
import com.taxiuap.backend.institution.dto.DatosEstudianteRequest;
import com.taxiuap.backend.institution.dto.DatosEstudianteResponse;
import com.taxiuap.backend.institution.dto.MatriculaRequest;
import com.taxiuap.backend.institution.dto.MatriculaResponse;
import com.taxiuap.backend.institution.entity.Estudiante;
import com.taxiuap.backend.institution.service.EstudianteService;
import com.taxiuap.backend.institution.service.MatriculaEstudianteService;
import com.taxiuap.backend.shared.response.ApiResponse;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/** Registro de datos de estudiante y matricula estudiantil del pasajero autenticado. */
@RestController
@RequestMapping("/api/pasajero/matricula")
@RequiredArgsConstructor
public class MatriculaEstudiantilController {

    private final EstudianteService estudianteService;
    private final MatriculaEstudianteService matriculaEstudianteService;

    @PutMapping("/datos-estudiante")
    public ResponseEntity<ApiResponse<DatosEstudianteResponse>> registrarOActualizarDatosEstudiante(
            @Valid @RequestBody DatosEstudianteRequest request) {
        Estudiante estudiante = estudianteService.registrarOActualizar(UsuarioActual.idUsuario(), request);
        DatosEstudianteResponse respuesta = new DatosEstudianteResponse(
                estudiante.getId(),
                estudiante.getInstitucion().getId(),
                estudiante.getInstitucion().getNombre(),
                estudiante.getCodigoEstudiante(),
                estudiante.getEstadoEstudiante()
        );
        return ResponseEntity.ok(ApiResponse.exito("Datos de estudiante guardados", respuesta));
    }

    @GetMapping
    public ResponseEntity<ApiResponse<List<MatriculaResponse>>> listarPropias() {
        return ResponseEntity.ok(ApiResponse.exito(matriculaEstudianteService.listarPropias(UsuarioActual.idUsuario())));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<MatriculaResponse>> registrar(@Valid @RequestBody MatriculaRequest request) {
        MatriculaResponse creada = matriculaEstudianteService.registrar(UsuarioActual.idUsuario(), request);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.exito("Matricula enviada a revision", creada));
    }
}
