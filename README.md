<img width="128" height="128" alt="image" src="https://raw.githubusercontent.com/PiCode9560/godot-csg-mesh-editor/91f07c0d3825661978ac69829dd585561416f35c/icon.svg" />

# CSG Mesh Editor

A simple non-destructive mesh editor based on the CSG nodes.

Make 3D models directly from the Mesh resource using CSG nodes. Perfect for prototyping levels, or prototyping assets.

### More than just CSG
This plugin is not just as simple as the CSG `baked mesh instance` option. This plugin allow you to edit mesh as CSG in a **non-destructive way**; You can edit a mesh as CSG, then apply it back to the mesh. Later on, you can edit the mesh again and it will bring back the previous CSG nodes.


https://github.com/user-attachments/assets/94a18b24-2838-41e7-83dd-10d93afa20f3


## Usage


- Select mesh instances that have a mesh assigned.
- In the toolbar at the top of the 3D screen, click on `CSGMeshEditor -> edit_mesh_as_CSG`.
- A csg tree will be added as a child of the mesh instance. Edit the CSGs like you would normally do.
- When you are done, apply the changes back to the mesh by `CSGMeshEditor -> apply_CSG_to_current_mesh / apply_CSG_to_new_mesh`.
- The CSG changes are stored as a metadata of the mesh resource, so you can edit the mesh again and your CSG nodes will be brought back.

<img width="299" height="207" alt="Screenshot 2026-03-23 093544" src="https://github.com/user-attachments/assets/44cfc3b8-c4b6-40cc-a785-d68515961025" />  <img width="334" height="140" alt="image" src="https://github.com/user-attachments/assets/d02f9d5a-3790-44ee-8a3a-2b834925eedd" />





