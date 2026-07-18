String? mathVisualTemplateSvg(String? template) {
  final key = _normalize(template);
  return switch (key) {
    'linear_function' || 'funcao_linear' || 'função_linear' => _linear(),
    'quadratic_function' ||
    'funcao_quadratica' ||
    'função_quadrática' => _quadratic(),
    'unit_circle' || 'circulo_unitario' || 'círculo_unitário' => _unitCircle(),
    'kinematics_s_t' || 'cinematica_s_t' || 'cinemática_s_t' => _kinematicsSt(),
    'kinematics_v_t' || 'cinematica_v_t' || 'cinemática_v_t' => _kinematicsVt(),
    _ => null,
  };
}

String _normalize(String? value) => (value ?? '')
    .trim()
    .toLowerCase()
    .replaceAll('-', '_')
    .replaceAll(' ', '_');

String _frame(String body) =>
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 420 560" role="img">'
    '<rect width="420" height="560" fill="#fffdf7"/>'
    '<rect x="28" y="38" width="364" height="484" rx="8" fill="#ffffff" stroke="#243042" stroke-width="2"/>'
    '$body</svg>';

String _axis() =>
    '<line x1="70" y1="430" x2="350" y2="430" stroke="#243042" stroke-width="2"/>'
    '<line x1="70" y1="430" x2="70" y2="120" stroke="#243042" stroke-width="2"/>'
    '<text x="336" y="456" font-size="18" fill="#243042">x</text>'
    '<text x="48" y="132" font-size="18" fill="#243042">y</text>';

String _linear() => _frame(
  '${_axis()}'
  '<line x1="86" y1="396" x2="330" y2="168" stroke="#0f766e" stroke-width="5"/>'
  '<circle cx="176" cy="312" r="6" fill="#dc2626"/>'
  '<text x="96" y="88" font-size="24" fill="#243042">Funcao linear</text>'
  '<text x="210" y="304" font-size="18" fill="#243042">y = ax + b</text>',
);

String _quadratic() => _frame(
  '${_axis()}'
  '<path d="M95 380 Q210 110 325 380" fill="none" stroke="#7c3aed" stroke-width="5"/>'
  '<circle cx="210" cy="186" r="6" fill="#dc2626"/>'
  '<text x="92" y="88" font-size="24" fill="#243042">Funcao quadratica</text>'
  '<text x="218" y="204" font-size="18" fill="#243042">vertice</text>',
);

String _unitCircle() => _frame(
  '<circle cx="210" cy="285" r="130" fill="#eef6ff" stroke="#2563eb" stroke-width="4"/>'
  '<line x1="70" y1="285" x2="350" y2="285" stroke="#243042" stroke-width="2"/>'
  '<line x1="210" y1="145" x2="210" y2="425" stroke="#243042" stroke-width="2"/>'
  '<line x1="210" y1="285" x2="302" y2="193" stroke="#dc2626" stroke-width="5"/>'
  '<path d="M252 285 A42 42 0 0 0 240 255" fill="none" stroke="#f59e0b" stroke-width="4"/>'
  '<text x="108" y="88" font-size="24" fill="#243042">Circulo unitario</text>'
  '<text x="258" y="246" font-size="18" fill="#243042">raio 1</text>',
);

String _kinematicsSt() => _frame(
  '${_axis()}'
  '<line x1="90" y1="392" x2="330" y2="168" stroke="#0ea5e9" stroke-width="5"/>'
  '<text x="96" y="88" font-size="24" fill="#243042">Grafico S-T</text>'
  '<text x="302" y="456" font-size="18" fill="#243042">tempo</text>'
  '<text x="38" y="152" font-size="18" fill="#243042">posicao</text>'
  '<text x="180" y="300" font-size="18" fill="#243042">velocidade constante</text>',
);

String _kinematicsVt() => _frame(
  '${_axis()}'
  '<line x1="90" y1="282" x2="330" y2="282" stroke="#16a34a" stroke-width="5"/>'
  '<rect x="90" y="282" width="240" height="148" fill="#bbf7d0" opacity="0.55"/>'
  '<text x="96" y="88" font-size="24" fill="#243042">Grafico V-T</text>'
  '<text x="302" y="456" font-size="18" fill="#243042">tempo</text>'
  '<text x="44" y="152" font-size="18" fill="#243042">vel.</text>'
  '<text x="150" y="356" font-size="18" fill="#243042">area = deslocamento</text>',
);
