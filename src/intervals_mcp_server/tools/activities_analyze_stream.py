"""
Server-side activity stream analysis MCP tool for Intervals.icu.

This module contains the analyze_activity_stream tool, which processes full
activity time-series data server-side and returns compact aggregate statistics.
"""

from typing import Any

from intervals_mcp_server.api.client import make_intervals_request

# Import mcp instance from shared module for tool registration
from intervals_mcp_server.mcp_instance import mcp  # noqa: F401


# Samples further apart than this are treated as recording pauses and excluded
# from time-weighted statistics.
_MAX_SAMPLE_GAP_SECONDS = 30

_SPEED_METRICS = {"velocity_smooth"}


def _analyze_stream_values(
    times: list[float],
    values: list[float | None],
    thresholds: list[float],
) -> dict[str, Any]:
    """Compute time-weighted aggregate statistics over a time-series stream.

    Each inter-sample gap is attributed to the later sample's value. Gaps longer
    than _MAX_SAMPLE_GAP_SECONDS (recording pauses) and null samples are excluded.

    Returns a dict with tracked_time, min/max/avg, and per-threshold time above.
    """
    tracked_time = 0.0
    weighted_sum = 0.0
    observed: list[float] = [v for v in values if v is not None]
    time_above = dict.fromkeys(thresholds, 0.0)

    for i in range(1, min(len(times), len(values))):
        dt = times[i] - times[i - 1]
        value = values[i]
        if dt <= 0 or dt > _MAX_SAMPLE_GAP_SECONDS or value is None:
            continue
        tracked_time += dt
        weighted_sum += value * dt
        for threshold in thresholds:
            if value > threshold:
                time_above[threshold] += dt

    return {
        "sample_count": len(values),
        "tracked_time": tracked_time,
        "min": min(observed) if observed else None,
        "max": max(observed) if observed else None,
        "avg": weighted_sum / tracked_time if tracked_time > 0 else None,
        "time_above": time_above,
    }


def _format_seconds(seconds: float) -> str:
    """Format a duration in seconds as h:mm:ss or m:ss."""
    total = int(round(seconds))
    hours, remainder = divmod(total, 3600)
    minutes, secs = divmod(remainder, 60)
    if hours:
        return f"{hours}:{minutes:02d}:{secs:02d}"
    return f"{minutes}:{secs:02d}"


def _format_metric_value(value: float, metric: str) -> str:
    """Format a stream value, adding a km/h equivalent for speed metrics."""
    if metric in _SPEED_METRICS:
        return f"{value:.2f} m/s ({value * 3.6:.1f} km/h)"
    return f"{value:.1f}"


@mcp.tool()
async def analyze_activity_stream(
    activity_id: str,
    metric: str = "velocity_smooth",
    thresholds: list[float] | None = None,
    api_key: str | None = None,
) -> str:
    """Analyze the full time-series of one activity metric server-side and return aggregate statistics.

    Unlike get_activity_streams (which only previews raw data), this tool processes every
    sample of the stream and returns compact statistics, so it works for activities of any
    length. Use it for questions like "how much time was spent above 35 km/h / 250 W / 160 bpm".

    Args:
        activity_id: The Intervals.icu activity ID
        metric: Stream to analyze. One of: watts, heartrate, cadence, altitude, velocity_smooth
                (velocity_smooth is speed in m/s). Defaults to velocity_smooth.
        thresholds: Optional list of threshold values in the metric's native unit; for each,
                    the time spent strictly above it is reported. NOTE: velocity_smooth
                    thresholds must be given in m/s (e.g. 35 km/h = 35 / 3.6 = 9.72 m/s).
        api_key: The Intervals.icu API key (optional, will use API_KEY from .env if not provided)

    Returns:
        Sample count, tracked time, min/avg/max (time-weighted average, excluding recording
        pauses), and time above each requested threshold with percentage of tracked time.
        Speed values include km/h equivalents.
    """
    thresholds = thresholds or []
    result = await make_intervals_request(
        url=f"/activity/{activity_id}/streams",
        api_key=api_key,
        params={"types": f"time,{metric}"},
    )

    if isinstance(result, dict) and "error" in result:
        error_message = result.get("message", "Unknown error")
        return f"Error fetching activity streams: {error_message}"

    streams = (
        {str(s.get("type")): s.get("data", []) for s in result if isinstance(s, dict)}
        if isinstance(result, list)
        else {}
    )
    times = streams.get("time")
    values = streams.get(metric)

    if not times or not values:
        available = ", ".join(k for k in streams if k != "time") or "none"
        return (
            f"No '{metric}' stream found for activity {activity_id} "
            f"(available streams of the requested types: {available})."
        )

    stats = _analyze_stream_values(times, values, thresholds)

    lines = [
        f"Stream Analysis for {activity_id} ({metric}):",
        "",
        f"Data Points: {stats['sample_count']}",
        f"Tracked Time (excl. pauses): {_format_seconds(stats['tracked_time'])}",
    ]
    if stats["avg"] is not None:
        lines.append(f"Min: {_format_metric_value(stats['min'], metric)}")
        lines.append(f"Avg (time-weighted): {_format_metric_value(stats['avg'], metric)}")
        lines.append(f"Max: {_format_metric_value(stats['max'], metric)}")
    for threshold in thresholds:
        above = stats["time_above"][threshold]
        pct = (above / stats["tracked_time"] * 100) if stats["tracked_time"] > 0 else 0.0
        lines.append(
            f"Time above {_format_metric_value(threshold, metric)}: "
            f"{_format_seconds(above)} ({pct:.1f}% of tracked time)"
        )

    return "\n".join(lines)
