package com.taxiuap.backend;

import java.util.TimeZone;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class TaxiuapApplication {

	/** Hora de Bolivia sin importar la zona de la maquina (el servidor puede estar en UTC). */
	public static final String ZONA_HORARIA = "America/La_Paz";

	public static void main(String[] args) {
		TimeZone.setDefault(TimeZone.getTimeZone(ZONA_HORARIA));
		System.setProperty("user.timezone", ZONA_HORARIA);
		SpringApplication.run(TaxiuapApplication.class, args);
	}

}
