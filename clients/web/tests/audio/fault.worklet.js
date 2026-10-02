class FaultInjectionProcessor extends AudioWorkletProcessor {
  constructor() { super(); this.port.postMessage({ type: 'ready' }) }
  process() { throw new Error('Deliberate synthetic test processor failure') }
}
registerProcessor('boohtacord-rnnoise', FaultInjectionProcessor)
