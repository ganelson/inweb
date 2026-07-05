document.addEventListener('DOMContentLoaded', function () {
	const scout = new SeekLocateDisplay({
	  container: '#docs-search',
	  placeholder: 'Search this web...',
	  pages: SEARCHDATA,
	  onNavigate: function (url) {
		window.location.href = url;
	  }
	});
}); // end DOMContentLoaded
