String? validateEmail(String? value) {
  final v = (value ?? '').trim();
  if (v.isEmpty) return 'Informe seu e-mail';
  final re = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  if (!re.hasMatch(v)) return 'E-mail invalido';
  return null;
}

String? validatePassword(String? value) {
  final v = value ?? '';
  if (v.length < 8) return 'A senha precisa de pelo menos 8 caracteres';
  final hasLetter = RegExp(r'[A-Za-z]').hasMatch(v);
  final hasNumber = RegExp(r'[0-9]').hasMatch(v);
  if (!hasLetter || !hasNumber) return 'Use letras e numeros';
  return null;
}

String? validatePasswordConfirmation(String? value, String password) {
  if (value != password) return 'As senhas nao coincidem';
  return null;
}

String? validateUfvEmail(String? value) {
  final base = validateEmail(value);
  if (base != null) return base;
  final v = value!.trim().toLowerCase();
  if (!v.endsWith('@ufv.br') && !v.endsWith('@alunos.ufv.br')) {
    return 'Use seu e-mail institucional @ufv.br ou @alunos.ufv.br';
  }
  return null;
}

int ageFromDate(DateTime date) {
  final now = DateTime.now();
  var age = now.year - date.year;
  if (now.month < date.month ||
      (now.month == date.month && now.day < date.day)) {
    age--;
  }
  return age;
}
