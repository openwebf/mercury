let seconds = 0;

const hello = async () => {
  const res = await fetch('https://api.ipify.org');
  const txt = await res.text();
  setInterval(() => {
    mercury.dispatcher.dispatch('example', { message: `${txt}: ${seconds} seconds.`});
    seconds++;
  }, 1000)
};
