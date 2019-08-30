# MetalGraphicsPlayground

This workspace contains subprojects for testing Metal features.
Requires Xcode 10 or later.

## Rendering Engine (work in progress)

**MetalDeferred** and **MetalPostProcessing** use deferred rendering based PBR frameworks.
You can check framework sources codes in **Common** directory!


**Features**
* Deferred Rendering
  * Light pre-pass based
  * G-buffer pass : Albedo, Normal, Tangent, Shading, Depth
  * Light pass : Light + Shadow Accumulation
  * Shade pass : Convolution
* Image based Lighting
  * HDRI Image (Equirectangular map -> Cubemap)
  * Split-sum approximation model
* Physically based Rendering
  * Metalic, Roughness, Anisotropic
* Light
  * Directional Light
  * Shadow (Bilinear, PCF)
* Post-processing
  * SSAO
* Frustum Culling
  * Sphere

**Render Pass**
<img src="./Screenshots/RenderPass.jpg" alt="Render Pass">

**Showcase Videos** (Click to watch)

[![Image based Lighting](https://img.youtube.com/vi/Z3z76WkNG6U/0.jpg)](https://www.youtube.com/watch?v=Z3z76WkNG6U)
[![Physically based Rendering](https://img.youtube.com/vi/aeZVjN5krqk/0.jpg)](https://www.youtube.com/watch?v=aeZVjN5krqk)
[![Light and Shadows](https://img.youtube.com/vi/aQeWSRoBLfU/0.jpg)](https://www.youtube.com/watch?v=aQeWSRoBLfU)

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

## MetalDeferred

<img src="./Screenshots/MetalDeferred.png" alt="MetalDeferred" width="605" height="533">

* Deferred Rendering
* Instancing
* PBR Lighting and Image based Lighting
* Referenced [LearnOpenGL](https://learnopengl.com/PBR/Theory)
* HDR Images from [sIBL Archive](http://www.hdrlabs.com/sibl/archive.html), which is licensed under [CC BY-NC-SA 3.0](http://creativecommons.org/licenses/by-nc-sa/3.0/us/)

## MetalPostProcessing

<img src="./Screenshots/MetalPostProcessing.png" alt="MetalPostProcessing.png" width="592" height="494">

* Under construction!
* Shadow-mapping (PCF)
* SSAO
* Frustum-Culling (Bounding Sphere)
* Gizmos
* TODO
  * Color grading (Tone mapping)
  * Depth of Field
  * Screen-space Reflection
  * Axis-Aligned Bounding Box
