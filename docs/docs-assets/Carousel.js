// Next/previous controls
function carouselMoveSlide(id, did, n) {
	carouselSetSlide(id, did, carouselGetSlide(id, did) + n);
}

function carouselGetSlide(id, did) {
	var carousel = document.getElementById(id);
	var slides = carousel.getElementsByClassName("carousel-slide");
	var i;
	for (i = 0; i < slides.length; i++) {
		if (slides[i].style.display == "block") {
			return i;
		}
	}
	return 0;
}

function carouselSetSlide(id, did, n) {
	var carousel = document.getElementById(id);
	var dotrow = document.getElementById(did);
	var i;
	var slides = carousel.getElementsByClassName("carousel-slide");
	var dots = dotrow.getElementsByClassName("carousel-dot");
	if (n >= slides.length) { n = 0 } 
	if (n < 0) { n = slides.length - 1 }
	for (i = 0; i < slides.length; i++) {
		if (i != n) {
			slides[i].style.display = "none";
			dots[i].className = "carousel-dot";
		} else {
			slides[i].style.display = "block";
			dots[i].className = "carousel-dot carousel-dot-active";
		}
	}
}
