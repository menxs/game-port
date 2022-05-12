export let InsiderHooks = {}
InsiderHooks.InfoCard = {
  mounted() {
    var infoRole = document.getElementById("info-role");
    var targetWord = document.getElementById("target-word");

    function show() {
      infoRole.style.opacity = 1
      targetWord.style.opacity = 1
    }

    function hide() {
      if (infoRole.getAttribute("role") != "master") {
        infoRole.style.opacity = 0
      }
      targetWord.style.opacity = 0
    }

    var infoCard = document.getElementById("info-card");
    infoCard.addEventListener("mousedown", show);
    infoCard.addEventListener("mouseup", hide);
    infoCard.addEventListener("mouseleave", hide);
  }
}

InsiderHooks.Timer = {
  mounted() {

    var timerEl = this.el;
    var timeoutDate = new Date(timerEl.getAttribute("timeout-date")).getTime();

    update_time = function() {

    var now = new Date().getTime();

    var time = timeoutDate - now;

    var minutes = Math.floor((time % (1000 * 60 * 60)) / (1000 * 60));
    var seconds = Math.floor((time % (1000 * 60)) / 1000);


      timerEl.innerHTML =
        String(minutes).padStart(2, '0') + ":" + String(seconds).padStart(2, '0');
      if (time < 0) {
          clearInterval(x);
        }
    }

    update_time();

    var x = setInterval(update_time, 1000);

    clearTime = function(el) {
      if (el == timerEl) {clearInterval(x)};
    }

  },
  updated() {
      update_time();
  },
  destroyed() {
    clearTime(this.el);
  }
}
