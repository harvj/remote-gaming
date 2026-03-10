<script>
  import { onMount, onDestroy } from "svelte";

  export let timestamp;

  let label = "";
  let timer;

  function getThen() {
    return new Date(timestamp).getTime();
  }

  function getDiff() {
    return Math.max(0, Date.now() - getThen());
  }

  function format(diffMs) {
    const secondsTotal = Math.floor(diffMs / 1000);
    const minutesTotal = Math.floor(diffMs / 60000);

    const days = Math.floor(minutesTotal / 1440);
    const hours = Math.floor((minutesTotal % 1440) / 60);
    const minutes = minutesTotal % 60;

    if (secondsTotal < 60) return `${secondsTotal}s`;
    if (minutesTotal < 60) return `${minutesTotal}m`;
    if (minutesTotal < 1440) {
      if (minutes === 0) return `${hours}h`;
      return `${hours}h ${minutes}m`;
    }

    if (hours === 0) return `${days}d`;
    return `${days}d ${hours}h`;
  }

  function nextDelay(diffMs) {
    const secondsTotal = Math.floor(diffMs / 1000);
    const minutesTotal = Math.floor(diffMs / 60000);

    if (secondsTotal < 60) {
      return 1000 - (diffMs % 1000);
    }

    if (minutesTotal < 60) {
      return 60000 - (diffMs % 60000);
    }

    return 3600000 - (diffMs % 3600000);
  }

  function tick() {
    const diffMs = getDiff();
    label = format(diffMs);

    clearTimeout(timer);
    timer = setTimeout(tick, nextDelay(diffMs));
  }

  onMount(() => {
    tick();
  });

  onDestroy(() => {
    clearTimeout(timer);
  });
</script>

<span>{label}</span>
