(() => {
  if (customElements.get('hocluc-logo')) return

  class HocLucLogo extends HTMLElement {
    static get observedAttributes() {
      return ['size', 'light']
    }

    connectedCallback() {
      this.render()
    }

    attributeChangedCallback() {
      if (this.isConnected) this.render()
    }

    render() {
      const parsedSize = Number(this.getAttribute('size') || 21)
      const size = Number.isFinite(parsedSize) ? Math.max(16, Math.min(parsedSize, 40)) : 21
      const light = this.hasAttribute('light')
      const root = this.shadowRoot || this.attachShadow({ mode: 'open' })
      root.innerHTML = `
        <style>
          :host { display: inline-flex; vertical-align: middle; }
          .wordmark {
            color: ${light ? '#fff' : 'var(--logo-color, var(--blue, #1cb0f6))'};
            display: inline-flex;
            align-items: baseline;
            font-family: inherit;
            font-size: ${size}px;
            font-weight: 900;
            letter-spacing: -.65px;
            line-height: 1.2;
            white-space: nowrap;
            text-shadow: 0 1px 0 #0797d6, 0 2px 0 #0797d6, 0 3px 0 #087fb5;
          }
          .dot {
            color: #f4b72e;
            text-shadow: 0 1px 0 #dda021, 0 2px 0 #dda021, 0 3px 0 #bd8419;
          }
          @media (max-width: 480px) {
            .wordmark { text-shadow: 0 1px 0 #0797d6, 0 2px 0 #087fb5; }
            .dot { text-shadow: 0 1px 0 #dda021, 0 2px 0 #bd8419; }
          }
        </style>
        <span class="wordmark" part="wordmark">hocluc<span class="dot" part="dot">.</span>com</span>
      `
    }
  }

  customElements.define('hocluc-logo', HocLucLogo)
})()
