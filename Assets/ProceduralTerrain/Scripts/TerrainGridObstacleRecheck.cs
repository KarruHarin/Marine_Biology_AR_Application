using UnityEngine;

// Re-runs the sandbox's obstacle scan after streamed-in terrain props have appeared, so grid
// cells sitting on a coral/seaweed turn red (unusable) — matching how rocks block cells in the
// stock environments. Needed because procedural props spawn a moment AFTER GridManager's
// one-time scan. Reuses GridCellScript.MarkAsUnusable(); it does NOT modify GridManager.
// Marine-app only (references GridManager/GridCellScript). No-op if no grid exists (AR scene).
public class TerrainGridObstacleRecheck : MonoBehaviour
{
    [Tooltip("Tag the props are given so the grid treats them as obstacles.")]
    public string obstacleTag = "Obstacle";
    [Tooltip("How often to re-scan, seconds.")]
    public float scanInterval = 1f;
    [Tooltip("Keep re-scanning for this long after start (covers streaming-in props).")]
    public float scanForSeconds = 6f;
    [Tooltip("Vertical half-height of the per-cell overlap test (matches GridManager).")]
    public float checkHalfHeight = 1.5f;

    readonly Collider[] _hits = new Collider[16];
    float _timer, _elapsed;

    void Update()
    {
        _elapsed += Time.deltaTime;
        if (_elapsed > scanForSeconds) { enabled = false; return; }

        _timer += Time.deltaTime;
        if (_timer < scanInterval) return;
        _timer = 0f;

        GridManager[] managers = FindObjectsByType<GridManager>(FindObjectsSortMode.None);
        for (int m = 0; m < managers.Length; m++)
        {
            GameObject[,] grid = managers[m].GetGrid();
            if (grid == null) continue;

            for (int x = 0; x < grid.GetLength(0); x++)
            for (int y = 0; y < grid.GetLength(1); y++)
            {
                GameObject cell = grid[x, y];
                if (cell == null) continue;
                GridCellScript script = cell.GetComponent<GridCellScript>();
                if (script == null || script.isOccupied) continue; // skip actor/already-blocked cells

                Vector3 ls = cell.transform.localScale; // GridManager sets this to (w, w, h)
                int n = Physics.OverlapBoxNonAlloc(
                    cell.transform.position,
                    new Vector3(ls.x * 0.45f, checkHalfHeight, ls.z * 0.45f),
                    _hits, Quaternion.identity, ~0, QueryTriggerInteraction.Ignore);

                for (int i = 0; i < n; i++)
                {
                    Collider h = _hits[i];
                    if (h == null) continue;
                    if (h.GetComponent<GridCellScript>() != null) continue; // ignore the cells themselves
                    if (h.CompareTag(obstacleTag)) { script.MarkAsUnusable(); break; }
                }
            }
        }
    }
}
