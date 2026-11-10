/// Explicaciones en lenguaje llano para la pestaña "¿Qué hacer?".
/// Textos del prototipo, revisados y completados para motos, camiones y
/// barcos.
abstract final class MaintenanceHelp {
  static const _texts = {
    'aceite':
        'El aceite lubrica las piezas del motor para que no se desgasten. Con el tiempo pierde sus propiedades aunque no hagas muchos km, y un motor con aceite viejo se estropea antes.',
    'filtro_aceite':
        'Atrapa la suciedad del aceite. Se cambia a la vez que el aceite y cuesta muy poco.',
    'filtro_aire':
        'Evita que el polvo entre en el motor. Un filtro sucio le resta potencia y hace que gaste más combustible.',
    'filtro_combustible':
        'Retiene las impurezas del combustible antes de que lleguen a los inyectores. En los diésel es especialmente importante.',
    'bujias':
        'Generan la chispa que enciende la mezcla en los motores de gasolina. Si están gastadas, el motor tira peor, gasta más o cuesta arrancarlo.',
    'correa_distribucion':
        'Muy importante. Sincroniza las piezas internas del motor. En muchos motores, si se rompe, la avería es muy cara. Respeta los km o los años, lo que llegue antes. Algunos motores llevan cadena en lugar de correa: tu taller te lo confirma.',
    'refrigerante':
        'Evita que el motor se caliente en verano y que el circuito se congele en invierno. Si falta o está degradado, el motor puede sufrir una avería grave.',
    'filtro_habitaculo':
        'Filtra el aire que respiras dentro del vehículo. Si está sucio, entra polvo y polen, y la ventilación pierde fuerza.',
    'frenos_delanteros':
        'Las pastillas rozan contra el disco para frenar. Cuando se gastan, el vehículo tarda más en detenerse. Si al frenar oyes un chirrido metálico, revísalas cuanto antes.',
    'frenos_traseros':
        'Igual que las delanteras, pero en el eje trasero. Se gastan más despacio, pero también hay que vigilarlas.',
    'discos_delanteros':
        'Son la pieza metálica sobre la que frenan las pastillas. Se gastan más despacio; si vibran al frenar, conviene revisarlos.',
    'frenos':
        'Las zapatas o pastillas de un vehículo pesado trabajan mucho. Un freno gastado alarga la distancia de frenado y es peligroso con carga.',
    'liquido_frenos':
        'Transmite la fuerza del pedal a los frenos. Con el tiempo absorbe humedad y pierde eficacia, por eso se cambia por años aunque hagas pocos km.',
    'neumaticos':
        'Son lo único que toca el suelo. Con el dibujo gastado se pierde agarre, sobre todo con lluvia. En España el mínimo legal es 1,6 mm, pero es mejor cambiarlos antes. La goma también envejece con los años.',
    'bateria':
        'Da la corriente para arrancar y para la electrónica. Suelen durar entre 4 y 5 años; el frío es cuando más fallan.',
    'itv':
        'Inspección técnica obligatoria en España. La frecuencia depende del tipo de vehículo y de su antigüedad: consulta la fecha en la pegatina o en tu tarjeta ITV.',
    'cadena_lubricado':
        'La cadena transmite la fuerza del motor a la rueda. Engrasarla con frecuencia (y después de rodar con lluvia) alarga mucho su vida.',
    'cadena_cambio':
        'El kit de arrastre (cadena, piñón y corona) se cambia completo. Una cadena destensada o muy gastada puede salirse o romperse.',
    'tacografo':
        'Registra tiempos de conducción y descanso. La revisión periódica en un taller autorizado es obligatoria por ley.',
    'anodos':
        'Piezas de zinc o aluminio que se desgastan en lugar del casco, la cola o la hélice por la corrosión del agua salada. Se cambian cuando están medio consumidas.',
    'revision_general':
        'Revisión anual del motor, cascos, bombas de achique y seguridad a bordo, idealmente antes de empezar la temporada.',
  };

  static const fallback =
      'Revisión recomendada para este tipo de vehículo. Tu taller puede indicarte qué incluye exactamente.';

  static String of(String itemId) => _texts[itemId] ?? fallback;

  static bool has(String itemId) => _texts.containsKey(itemId);
}
