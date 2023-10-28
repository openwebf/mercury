
console.log('bundle is running');

var hello = () => {
  console.log('hello from bundle!');
  //Dispatcher.dispatch('example', JSON.stringify({ message: 'Hello from JavaScript!'}))
};

class MercuryDispatcher extends EventTarget {
  constructor() {
    super();
  }

  dispatch(data1, data2) {
    console.log('call dispatch event');
    this.dispatchToDart(data1, data2);
  }
}

const mercuryDispatcher = new MercuryDispatcher();
mercuryDispatcher.addEventListener('click', () => {})
mercuryDispatcher.dispatch('helloworld', { name: 1})
