String parseMessageKind(Object? value) {
  if (value == null || value == 'USER') return 'USER';
  if (value == 'SYSTEM_WELCOME') return 'SYSTEM_WELCOME';
  throw const FormatException('Invalid message kind.');
}
