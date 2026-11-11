class_name Texts
extends RefCounted

const NOTES: Dictionary = {
	"carta": {
		"title": "Carta sin sello",
		"body": "Necesito tu ayuda. Ven al faro cuanto antes.\n\nYa sé que la puerta está cerrada: tú lo quisiste así, para no perderte de noche. Haz el camino de siempre y encontrarás la llave.\n\nEmpieza por el armario donde siempre es invierno.\n\n— E.",
	},
	"nota_nevera": {
		"title": "Nota en la nevera",
		"body": "Comprar:\n  - leche\n  - pan\n  - pilas para la linterna\n\nNo olvides cerrar con llave.\n\n— E.",
	},
	"foto": {
		"title": "Una foto antigua",
		"body": "Un hombre con uniforme de farero sonríe delante de un faro blanco y rojo. Tiene tu cara, aunque más joven.\n\nPor detrás, con una letra que conoces muy bien:\n«Elías. Faro de Punta Negra, 1987.»",
	},
	"nota_comoda": {
		"title": "Nota doblada",
		"body": "Si estás leyendo esto, ya casi está.\n\nTu llave duerme donde tú sueñas.\n\n— E.",
	},
	"espejo": {
		"title": "Mensaje en el espejo",
		"body": "Mi ciudad se enciende cuando yo vigilo. Cuenta sus luces de la tarde a la mañana.",
	},
}

const MIRROR: String = "Mi ciudad se enciende\ncuando yo vigilo.\nCuenta sus luces\nde la tarde a la mañana."

const HINTS: Dictionary = {
	0: ["Alguien ha llamado a la puerta.", "Mira en la entrada."],
	1: ["Donde siempre es invierno...", "Lo frío se guarda en la cocina.", "Abre la nevera."],
	2: ["Las conchas guardan el sonido del mar.", "¿Dónde hay agua quieta en esta casa?", "Deja la concha en la bañera."],
	3: ["Mira los cuadros del pasillo.", "Cuenta las ventanas encendidas de cada edificio.",
		"Fíjate en la hora de cada reloj y ordénalos de la tarde a la mañana: 18, 21 y 3."],
	4: ["Tres números... ¿y dónde se usan?", "Algo metálico entre tu ropa.", "La caja fuerte del armario: 4 - 7 - 2."],
	5: ["Una llave pequeña para un cajón pequeño.", "La cómoda del fondo del pasillo."],
	6: ["¿Dónde duerme una llave?", "Donde tú sueñas...", "Mira debajo de la almohada."],
	7: ["Ya puedes salir.", "La puerta de la entrada."],
}

const SUBTITLES: Dictionary = {
	"intro_silencio": "...",
	"timbre": "Han llamado a la puerta.",
	"diario": "Pulsa Tab para releer lo que has leído.",
	"concha": "Si la acercas al oído, suena a mar.",
	"nevera": "¿Una concha... dentro de la nevera?",
	"espejo": "Algo ha aparecido en el espejo del baño.",
	"foto": "Elías... La carta iba firmada con una «E».",
	"llave_portal": "La llave de casa.",
	"tele_apagada": "La tele está apagada.",
	"diario_vacio": "Todavía no has leído nada.",
	"inventario_lleno": "No puedes llevar más cosas. Deja algo con el botón derecho.",
	"bañera": "El borde de la bañera... aquí encajaría algo del mar.",
}

const ENDING_TITLE: String = "Gracias por jugar la demo"
const ENDING_HINT: String = "Pulsa Esc para salir"
const TV_IDLE: String = "SIN SEÑAL"
const UNLOCKED: String = "Abierto"
const LOCKED: String = "Está cerrado con llave"
const SAFE_TITLE: String = "Caja fuerte"
const NOTE_HELP: String = "Clic para cerrar  ·  Tab: diario"
const JOURNAL_HELP: String = "Diario %d/%d  ·  ← → para pasar  ·  Tab o clic para cerrar"
const KEYPAD_HELP: String = "Haz clic en los números o escríbelos · Enter: abrir · Esc: salir"
