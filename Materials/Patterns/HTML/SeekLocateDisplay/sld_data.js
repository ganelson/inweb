document.addEventListener('DOMContentLoaded', function () {
	const scout = new SeekLocateDisplay({
	  container: '#docs-search',
	  placeholder: '[[Search Text]]',
	  pages: [[Search Data]],
	  onNavigate: function (url) {
		window.location.href = url;
	  }
	});
}); // end DOMContentLoaded
