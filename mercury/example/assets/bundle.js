console.log('does this even work?');

mercury.methodChannel.addMethodCallHandler('test', function(state) {
  // Here, 'state' holds the data sent from Dart.

  console.log(typeof state['test'])

  console.log('Received state: ' + JSON.stringify(state));

  // You can also send back a response to Dart, if needed.
  return {
    message: 'Received state successfully.',
    testing: 127,
  };
});

let seconds = 0;

console.log('how about here?')

// const hello = async () => {
//   //const res = await fetch('https://api.ipify.org');
//   //const txt = await res.text();
//   setInterval(() => {
//     console.log('yup')
//     mercury.dispatcher.dispatch('example', { message: `foo: ${seconds} seconds.`});
//     seconds++;
//   }, 1000)
// };

console.log('surely not')
