import 'package:pdfium_dart/pdfium_dart.dart';

void main() {
  final pdfium = getPdfium();
  pdfium.FPDF_InitLibrary();
  pdfium.FPDF_DestroyLibrary();
}
