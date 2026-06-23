using UnityEngine;

// Finds placed actors by their tag and gives each a GroundOnTerrain so they snap onto the
// seabed instead of sinking into it. Zero coupling: works purely off the "Actor" tag, never
// referencing any host class. Drop this on the terrain prefab; it auto-runs when placed.
public class TerrainActorGrounder : MonoBehaviour
{
    [Tooltip("Tag of objects to ground (the app tags placed creatures 'Actor').")]
    public string actorTag = "Actor";
    [Tooltip("How often to scan for newly spawned actors, in seconds.")]
    public float scanInterval = 0.5f;
    [Tooltip("Stop scanning after this long — actors are placed once, near start.")]
    public float scanForSeconds = 10f;

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
        catch { enabled = false; return; } // tag not defined in this project — nothing to do

        for (int i = 0; i < actors.Length; i++)
            if (actors[i].GetComponent<GroundOnTerrain>() == null)
                actors[i].AddComponent<GroundOnTerrain>();
    }
}
