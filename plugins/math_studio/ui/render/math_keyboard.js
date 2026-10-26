/**
 * Academic Math Formula Helper & Quick Keypad
 * Cung cấp cơ chế nhập liệu công thức toán học THPT mượt mà, không giật lag con trỏ.
 */

export class MathKeyboardHelper {
  constructor(inputElement, previewElement, onExpressionChange) {
    this.input = inputElement;
    this.preview = previewElement;
    this.onChange = onExpressionChange;
    this.setupListeners();
  }

  setupListeners() {
    if (!this.input) return;

    this.input.addEventListener('input', (e) => {
      this.updateVisualPreview();
      if (this.onChange) {
        this.onChange(this.input.value);
      }
    });

    this.input.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') {
        if (this.onChange) this.onChange(this.input.value);
      }
    });

    this.updateVisualPreview();
  }

  insertText(prefix, suffix = '') {
    if (!this.input) return;
    const start = this.input.selectionStart ?? this.input.value.length;
    const end = this.input.selectionEnd ?? this.input.value.length;
    const val = this.input.value;

    const selected = val.substring(start, end);
    const replacement = prefix + selected + suffix;

    this.input.value = val.substring(0, start) + replacement + val.substring(end);
    this.input.focus();

    const newCursor = start + prefix.length + selected.length;
    this.input.setSelectionRange(newCursor, newCursor);

    this.updateVisualPreview();
    if (this.onChange) this.onChange(this.input.value);
  }

  setExpression(expr) {
    if (!this.input) return;
    this.input.value = expr;
    this.updateVisualPreview();
    if (this.onChange) this.onChange(expr);
  }

  /**
   * Chuyển đổi chuỗi văn bản sang ký hiệu toán học chuẩn mực
   */
  formatToAcademicPreview(raw) {
    if (!raw || !raw.trim()) {
      return '<span class="math-placeholder">Nhập hàm số f(x)...</span>';
    }

    let formatted = raw.trim();

    // 1. Phân số dạng (A)/(B) hoặc A/B
    formatted = formatted.replace(/\(([^()]+)\)\s*\/\s*\(([^()]+)\)/g, '<span class="frac"><span class="num">$1</span><span class="den">$2</span></span>');
    formatted = formatted.replace(/([a-zA-Z0-9_\^]+)\s*\/\s*([a-zA-Z0-9_\^]+)/g, '<span class="frac"><span class="num">$1</span><span class="den">$2</span></span>');

    // 2. Căn bậc hai sqrt(...)
    formatted = formatted.replace(/sqrt\(([^()]+)\)/g, '<span class="sqrt-wrap"><span class="sqrt-sym">√</span><span class="sqrt-body">$1</span></span>');

    // 3. Số mũ x^3 -> x³, x^2 -> x², x^n -> xⁿ
    formatted = formatted.replace(/\^2/g, '²');
    formatted = formatted.replace(/\^3/g, '³');
    formatted = formatted.replace(/\^([0-9a-zA-Z]+)/g, '<sup>$1</sup>');
    formatted = formatted.replace(/\^\(([^()]+)\)/g, '<sup>$1</sup>');

    // 4. Nhân * -> ·
    formatted = formatted.replace(/\*/g, ' · ');

    // 5. Hàm lượng giác in thẳng đứng
    formatted = formatted.replace(/\b(sin|cos|tan|cot|ln|log)\b/g, '<span class="math-func">$1</span>');

    return `<span class="math-y-prefix">y =</span> <span class="math-body">${formatted}</span>`;
  }

  updateVisualPreview() {
    if (!this.preview) return;
    this.preview.innerHTML = this.formatToAcademicPreview(this.input ? this.input.value : '');
  }
}
