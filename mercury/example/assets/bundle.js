let seconds = 0;

const hello = () => {
  setInterval(() => {
    mercury.dispatcher.dispatch('example', { message: `Hello from JavaScript! It has been ${seconds} seconds.`});
    seconds++;
  }, 1000)
};
