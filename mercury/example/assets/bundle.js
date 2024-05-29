console.log('does this even work?');

let seconds = 0;

console.log('how about here?')

const hello = async () => {
  //const res = await fetch('https://api.ipify.org');
  //const txt = await res.text();
  setInterval(() => {
    console.log('yup')
    mercury.dispatcher.dispatch('example', { message: `foo: ${seconds} seconds.`});
    seconds++;
  }, 1000)
};

console.log('surely not')
