# CSG Mesh Editor

A plugin that allow you to edit the geometry of a mesh resource using the CSG nodes. Perfect for prototyping levels, or 3D models.

## Usage

- Select mesh instances that have a mesh assigned.
- In the toolbar at the top of the 3D screen, click on `CSGMeshEditor -> edit_mesh_as_CSG`.
- A csg tree will be added as a child of the mesh instance. Edit the CSGs like you would normally do.
- When you are done, apply the changes back to the mesh by `CSGMeshEditor -> apply_CSG_to_current_mesh / apply_CSG_to_new_mesh`.
- The CSG changes are stored as a metadata of the mesh resource, so you can edit the mesh again and your CSG nodes will be brought back.

![]("https://github.com/user-attachments/assets/2909825e-ec9d-4ca3-a432-f60cc68dd0bf")

Vertical layout           |  Horizontal layout
:-------------------------:|:-------------------------:
<img width="299" height="207" alt="Screenshot 2026-03-23 093544" src="https://github.com/user-attachments/assets/44cfc3b8-c4b6-40cc-a785-d68515961025" /> | <img width="334" height="140" alt="image" src="https://github.com/user-attachments/assets/d02f9d5a-3790-44ee-8a3a-2b834925eedd" />

