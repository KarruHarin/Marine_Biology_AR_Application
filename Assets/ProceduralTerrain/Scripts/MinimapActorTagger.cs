using UnityEngine;

// Makes placed actors (creatures) show up on the minimap by adding a MinimapMarker to each
// object with the given tag — so they appear via the registry regardless of whether they have
// colliders. Zero host coupling: works purely off the "Actor" tag, never references host classes.
public class MinimapActorTagger : MonoBehaviour
{
    [Tooltip("Tag of objects to show on the minimap (the app tags creatures 'Actor').")]
    public string actorTag = "Actor";
    [Tooltip("Blip colour for these actors on the radar.")]
    public Color actorColor = new Color(1f, 0.55f, 0.2f, 1f); // orange = creatures
    [Tooltip("How often to scan for newly spawned actors, seconds.")]
    public float scanInterval = 0.5f;
    [Tooltip("Stop scanning after this long — actors are placed once, near start.")]
    public float scanForSeconds = 12f;

    float _timer, _elapsed;

    void Update()
    {
        _elapsed += Time.deltaTime;
        if (_elapsed > scanForSeconds) { enabled = false; return; }

        _timer += Time.deltaTime;
        if (_timer < scanInterval) return;
        _timer = 0f;

        GameObject[] actors;
        try { actors = GameObject.FindGameObjectsWithTag(actorTag); }
        catch { enabled = false; return; } // tag not defined in this project

        for (int i = 0; i < actors.Length; i++)
            if (actors[i].GetComponent<MinimapMarker>() == null)
                actors[i].AddComponent<MinimapMarker>().color = actorColor;
    }
}
