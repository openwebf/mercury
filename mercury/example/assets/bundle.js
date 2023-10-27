function stupid() {
  console.log('maybe?');
  return 'hmm';
}
console.log('1');
//Object.defineProperty(global, 'stupid', { test: 15 });

var stupider = stupid
