using UnityEngine;

// Lifts an actor onto the procedural terrain surface so nothing sits buried in the seabed.
// RAISE-ONLY: it only moves the actor UP to the surface; actors already above it stay put
// (so mid-water/surface-layer creatures keep their depth). It retries while the terrain
// streams in (the chunk's collider may not exist the instant the actor spawns), then
// disables itself once grounded. Self-contained: no reference to any host class.
public class GroundOnTerrain : MonoBehaviour
{
    [Tooltip("Give up after this many seconds if no terrain has loaded under the actor.")]
    public float maxSeconds = 2.5f;
    [Tooltip("Start the downward ray this far above the actor.")]
    public float rayUp = 50f;
    [Tooltip("Total ray length (must reach below the deepest terrain).")]
    public float rayLength = 200f;
    [Tooltip("Sit this far above the surface so nothing clips into the sand.")]
    public float surfaceOffset = 0.05f;
    [Tooltip("EndlessTerrain names its chunk objects this — we only snap onto those.")]
    public string terrainChunkName = "Terrain Chunk";

    static readonly RaycastHit[] _buf = new RaycastHit[16];
    float _elapsed;

    void OnEnable() => _elapsed = 0f;

    void Update()
    {
        _elapsed += Time.deltaTime;

        Vector3 p = transform.position;
        Vector3 origin = new Vector3(p.x, p.y + rayUp, p.z);
        int n = Physics.RaycastNonAlloc(origin, Vector3.down, _buf, rayLength, ~0, QueryTriggerInteraction.Ignore);

        float bestY = float.NaN, bestDist = float.MaxValue;
        for (int i = 0; i < n; i++)
        {
            RaycastHit h = _buf[i];
            if (h.collider == null) continue;
            if (h.collider.gameObject.name != terrainChunkName) continue; // terrain only — never another actor
            if (h.distance < bestDist) { bestDist = h.distance; bestY = h.point.y; }
        }

        if (!float.IsNaN(bestY))
        {
            float targetY = bestY + surfaceOffset;
            if (transform.position.y < targetY) // raise-only
            {
                Vector3 np = transform.position; np.y = targetY; transform.position = np;
            }
            enabled = false; // grounded — done
            return;
        }

        if (_elapsed >= maxSeconds) enabled = false; // terrain never loaded here; give up
    }
}
