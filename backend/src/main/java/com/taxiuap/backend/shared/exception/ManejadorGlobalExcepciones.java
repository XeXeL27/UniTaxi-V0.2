package com.taxiuap.backend.shared.exception;

import java.util.LinkedHashMap;
import java.util.Map;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.AuthenticationException;
import org.springframework.validation.FieldError;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.HandlerMethodValidationException;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.multipart.MaxUploadSizeExceededException;
import org.springframework.web.multipart.MultipartException;
import org.springframework.web.multipart.support.MissingServletRequestPartException;
import org.springframework.web.servlet.resource.NoResourceFoundException;

import com.taxiuap.backend.shared.response.ApiResponse;

import jakarta.servlet.http.HttpServletRequest;
import lombok.extern.slf4j.Slf4j;

/**
 * Punto unico de conversion de excepciones a respuestas HTTP con el sobre {@link ApiResponse}.
 *
 * Existe por lo mismo que ManejadorErroresApi en uniFex: sin un manejador centralizado, una
 * excepcion en un controller termina en el forward interno a /error, que puede no responder el
 * JSON que espera el cliente (apps Flutter, panel admin). Aqui se controla explicitamente cada
 * caso y el codigo HTTP que le corresponde.
 *
 * Las excepciones de Spring Security (autenticacion y autorizacion) se relanzan sin tocar para
 * que las resuelva la propia cadena de seguridad (ver SecurityConfig); si se atraparan aqui,
 * @PreAuthorize terminaria respondiendo 500 en vez de 403.
 */
@RestControllerAdvice
@Slf4j
public class ManejadorGlobalExcepciones {

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ApiResponse<Void>> datosInvalidos(MethodArgumentNotValidException e) {
        Map<String, String> errores = new LinkedHashMap<>();
        for (FieldError fe : e.getBindingResult().getFieldErrors()) {
            errores.putIfAbsent(fe.getField(), fe.getDefaultMessage());
        }
        return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body(ApiResponse.error("Datos de entrada invalidos", errores));
    }

    @ExceptionHandler(HandlerMethodValidationException.class)
    public ResponseEntity<ApiResponse<Void>> datosInvalidos(HandlerMethodValidationException e) {
        return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body(ApiResponse.error("Datos de entrada invalidos"));
    }

    @ExceptionHandler({
            HttpMessageNotReadableException.class,
            MethodArgumentTypeMismatchException.class,
            MissingServletRequestParameterException.class,
            MissingServletRequestPartException.class,
            MultipartException.class
    })
    public ResponseEntity<ApiResponse<Void>> peticionInvalida(Exception e, HttpServletRequest peticion) {
        log.warn("Peticion invalida en {} {}: {}", peticion.getMethod(), peticion.getRequestURI(), e.getMessage());
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(ApiResponse.error("Peticion invalida"));
    }

    @ExceptionHandler(MaxUploadSizeExceededException.class)
    public ResponseEntity<ApiResponse<Void>> archivoMuyGrande(MaxUploadSizeExceededException e) {
        return ResponseEntity.status(HttpStatus.CONTENT_TOO_LARGE)
                .body(ApiResponse.error("El archivo supera el tamano maximo permitido (5 MB por archivo)"));
    }

    @ExceptionHandler(NegocioException.class)
    public ResponseEntity<ApiResponse<Void>> negocio(NegocioException e) {
        return ResponseEntity.status(HttpStatus.UNPROCESSABLE_CONTENT).body(ApiResponse.error(e.getMessage()));
    }

    @ExceptionHandler(RecursoNoEncontradoException.class)
    public ResponseEntity<ApiResponse<Void>> recursoNoEncontrado(RecursoNoEncontradoException e) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND).body(ApiResponse.error(e.getMessage()));
    }

    @ExceptionHandler(ConflictoException.class)
    public ResponseEntity<ApiResponse<Void>> conflicto(ConflictoException e) {
        return ResponseEntity.status(HttpStatus.CONFLICT).body(ApiResponse.error(e.getMessage()));
    }

    @ExceptionHandler(CredencialesInvalidasException.class)
    public ResponseEntity<ApiResponse<Void>> credencialesInvalidas(CredencialesInvalidasException e) {
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(ApiResponse.error(e.getMessage()));
    }

    @ExceptionHandler(NoResourceFoundException.class)
    public ResponseEntity<ApiResponse<Void>> recursoEstaticoNoEncontrado() {
        return ResponseEntity.status(HttpStatus.NOT_FOUND).body(ApiResponse.error("Recurso no encontrado"));
    }

    @ExceptionHandler(HttpRequestMethodNotSupportedException.class)
    public ResponseEntity<ApiResponse<Void>> metodoNoPermitido() {
        return ResponseEntity.status(HttpStatus.METHOD_NOT_ALLOWED).body(ApiResponse.error("Metodo no permitido"));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiResponse<Void>> fallo(Exception e, HttpServletRequest peticion) throws Exception {
        if (e instanceof AccessDeniedException || e instanceof AuthenticationException) {
            throw e;
        }
        log.error("Fallo no controlado en {} {}", peticion.getMethod(), peticion.getRequestURI(), e);
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(ApiResponse.error("Error interno procesando la peticion"));
    }
}
