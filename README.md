# MetalGraphicsPlayground

This workspace contains subprojects for testing Metal features.
Requires Xcode 11 or later.

## Rendering Engine (work in progress)

**MetalDeferred**, **MetalPostProcessing** and **MetalSceneGraph** use deferred rendering based PBR frameworks.
You can check framework sources codes in **Common** directory!

**Features**
* Deferred Rendering
  * Light pre-pass based
    * G-buffer pass : Albedo, Normal, Tangent, Shading, Depth
    * Light pass : Light + Shadow Accumulation
    * Shade pass : Convolution
  * Tile deferred
    * G-buffer pass : Albedo, Normal, Tangent, Shading, Depth
    * Light culling pass
    * Shade pass : Convolution
* Image based Lighting
  * HDRI Image (Equirectangular map -> Cubemap)
  * Split-sum approximation model
* Physically based Rendering
  * Metalic, Roughness, Anisotropic
* Light
  * Directional Light
  * Point Light
  * Shadow (Bilinear, PCF)
  * Light Culling (Tile-based)
* Post-processing
  * Screen-Space Ambient Occlusion
  * Screen-Space Reflection
* Frustum Culling
  * Sphere
* Scene Graph
  * Scene, Node, Component

**Render Pass**

<img src="./Screenshots/RenderPass.jpg" alt="Render Pass" width="390" height="562">

**Showcase Videos** (Click to watch)

[<img src="https://img.youtube.com/vi/Z3z76WkNG6U/0.jpg" alt="Image based Lighting" width="320" height="240">](https://www.youtube.com/watch?v=Z3z76WkNG6U)
[<img src="https://img.youtube.com/vi/aeZVjN5krqk/0.jpg" alt="Physically based Rendering" width="320" height="240">](https://www.youtube.com/watch?v=aeZVjN5krqk)
[<img src="https://img.youtube.com/vi/_raZEvfcWY4/0.jpg" alt="Light and Shadows" width="320" height="240">](https://www.youtube.com/watch?v=_raZEvfcWY4)
[<img src="https://img.youtube.com/vi/K6zhDj0YyPQ/0.jpg" alt="Post Processing" width="320" height="240">](https://www.youtube.com/watch?v=K6zhDj0YyPQ)


<details><summary>Samples (Legacy)</summary>
<p>

## MetalTextureLOD

<img src="./Screenshots/MetalTextureLOD.png" alt="MetalTextureLOD" width="592" height="494">

* Texture data updating and textureLOD in shader.

## MetalModels

<img src="./Screenshots/MetalModels.png" alt="MetalModels" width="592" height="494">

* ModelIO Test

## MetalMSAA

<img src="./Screenshots/MetalMSAA.png" alt="MetalMSAA" width="612" height="614">

* MSAA resolve

## MetalGeometry

<img src="./Screenshots/MetalGeometry.png" alt="MetalGeometry" width="624" height="646">

## MetalShadowMapping

<img src="./Screenshots/MetalShadowMapping.png" alt="MetalShadowMapping" width="592" height="494">

* Shadow mapping

## MetalIZBShadow

<img src="./Screenshots/MetalIZBShadow.png" alt="MetalIZBShadow" width="592" height="494">

* Just another shadow mapping test. NOT Irregular z-buffer :=(

## MetalEnvironmentMapping

<img src="./Screenshots/MetalEnvironmentMapping.png" alt="MetalEnvironmentMapping" width="592" height="512">

* PBR (Physically based rendering) (referenced UE4 shader docs)
  * Image based lighting (+ Environment mapping)
  * Prefilterd Irradiance Map
  * Metalic and roughness
  
## MetalInstancing

<img src="./Screenshots/MetalInstancing.png" alt="MetalInstancing" width="612" height="634">

* Instancing

</p>
</details>

## MetalDeferred

<img src="./Screenshots/MetalDeferred.png" alt="MetalDeferred" width="605" height="533">

* Deferred Rendering
* Instancing
* PBR Lighting and Image based Lighting
* Referenced [LearnOpenGL](https://learnopengl.com/PBR/Theory)
* HDR Images from [sIBL Archive](http://www.hdrlabs.com/sibl/archive.html), which is licensed under [CC BY-NC-SA 3.0](http://creativecommons.org/licenses/by-nc-sa/3.0/us/)

## MetalPostProcessing

<img src="./Screenshots/MetalPostProcessing.png" alt="MetalPostProcessing.png" width="592" height="635">

* Under construction!
* Shadow-mapping (PCF)
* Screen-Space Ambient Occlusion
* Screen-Space Reflection
* Frustum Culling (Sphere)
* Light Culling (Tile-based)
* Gizmos
* TODO
  * Color grading (Tone mapping)
  * Depth of Field
  * Axis-Aligned Bounding Box

  ## MetalSceneGraph

  <img src="./Screenshots/MetalPostProcessing.png" alt="MetalPostProcessing.png" width="592" height="635">

  * Scene Graph (Scene, Node, Component)
  * General-purpose renderer
