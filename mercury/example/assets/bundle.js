console.log('Javascript bundle -- start');

let seconds = 0;

const hello = async () => {
	const res = await fetch('https://api.ipify.org');
	var msg = await res.text();
	mercury.dispatcher.dispatch('example', { message: `url: ${msg}`});
	if (0) {
		setInterval(() => {
			console.log('yup')
			mercury.dispatcher.dispatch('example', { message: `foo: ${seconds} seconds.`});
			seconds++;
	  		}, 1000
		)
	}
};

console.log('Javascript bundle -- end');
