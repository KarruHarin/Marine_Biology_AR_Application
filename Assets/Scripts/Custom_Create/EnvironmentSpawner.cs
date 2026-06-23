using UnityEngine;
using System.Collections.Generic;

public class EnvironmentSpawner : MonoBehaviour
{
    public List<GameObject> allEnvironmentPrefabs; // Assign all prefabs in Inspector
    public Vector2 planeSizeInMeters = new Vector2(5, 5);
    private GameObject spawnedPlane;

    public void SpawnEnvironmentPlane()
    {
        if (spawnedPlane != null)
        {
            Debug.LogWarning("Plane already exists!");
            return;
        }

        string prefabName = PlayerPrefs.GetString("SelectedEnvironmentPrefabName", "");
        if (string.IsNullOrEmpty(prefabName))
        {
            Debug.LogError("No prefab name found in PlayerPrefs!");
            return;
        }

        GameObject prefabToSpawn = FindPrefabByName(prefabName);
        if (!prefabToSpawn)
        {
            Debug.LogError("Could not find prefab: " + prefabName);
            return;
        }

        float scaleX = planeSizeInMeters.x / 10f;
        float scaleZ = planeSizeInMeters.y / 10f;

        Vector3 spawnPosition = Camera.main.transform.position + Camera.main.transform.forward * 1.5f;
        spawnPosition.y = 0f;

        // Streaming terrain (EndlessTerrain) generates its chunks in world space and must NOT be
        // squashed to the bounded-plane footprint, or the seabed and water get distorted.
        bool isStreamingTerrain = prefabToSpawn.GetComponentInChildren<EndlessTerrain>(true) != null;

        spawnedPlane = Instantiate(prefabToSpawn, spawnPosition, Quaternion.identity);
        if (!isStreamingTerrain)
            spawnedPlane.transform.localScale = new Vector3(scaleX, 1f, scaleZ);
        spawnedPlane.name = "EnvironmentPlane";

        Debug.Log("Environment Plane spawned: " + prefabToSpawn.name +
                  (isStreamingTerrain ? " (streaming terrain, kept at scale 1)" : ""));
    }

    public GameObject GetSpawnedPlane() => spawnedPlane;

    private GameObject FindPrefabByName(string name)
    {
        foreach (var prefab in allEnvironmentPrefabs)
        {
            if (prefab.name == name)
                return prefab;
        }
        return null;
    }
}
