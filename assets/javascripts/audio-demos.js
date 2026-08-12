(() => {
  const selector = ".audio-demo audio";

  const initializeAudioDemos = () => {
    const players = Array.from(document.querySelectorAll(selector));

    players.forEach((player) => {
      if (player.dataset.audioDemoInitialized === "true") return;

      player.dataset.audioDemoInitialized = "true";
      player.preload = "metadata";

      player.addEventListener("play", () => {
        players.forEach((otherPlayer) => {
          if (otherPlayer !== player && !otherPlayer.paused) {
            otherPlayer.pause();
          }
        });
      });

      player.addEventListener("error", () => {
        const card = player.closest(".audio-demo");
        const source = player.querySelector("source");
        if (!card || !source || card.querySelector(".audio-demo__fallback")) return;

        const fallback = document.createElement("a");
        fallback.className = "audio-demo__fallback";
        fallback.href = source.src;
        fallback.textContent = "Open audio file";
        card.append(fallback);
      });

      if (player.readyState === HTMLMediaElement.HAVE_NOTHING) {
        player.load();
      }
    });
  };

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initializeAudioDemos, { once: true });
  } else {
    initializeAudioDemos();
  }

  if (typeof document$ !== "undefined") {
    document$.subscribe(initializeAudioDemos);
  }
})();
