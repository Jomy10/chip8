export class Timer {
  constructor(started, previous) {
    this.started = started;
    this.prvious = previous;
  }
  
  static start() {
    const current = Date.now();
    return new Timer(current, current);
  }

  read() {
    const current = Date.now();
    return current - this.started;
  }

  reset() {
    const current = Date.now();
    this.started = current;
  }
};
