package com.taxiuap.backend.identity.repository;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.lang.reflect.Method;

import org.junit.jupiter.api.Test;

import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.Lock;

class ConductorRepositoryLockTest {

    @Test
    void bloqueoDeConductorEsPesimistaParaSerializarAceptaciones() throws Exception {
        Method metodo = ConductorRepository.class.getMethod("bloquear", Long.class);

        assertEquals(LockModeType.PESSIMISTIC_WRITE, metodo.getAnnotation(Lock.class).value());
    }
}
