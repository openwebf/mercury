let seconds = 0;

const hello = async () => {
  const arix = await fetch('www.arix.com');
  setInterval(() => {
    mercury.dispatcher.dispatch('example', { message: `{arix}: ${seconds} seconds.`});
    seconds++;
  }, 1000)
};
