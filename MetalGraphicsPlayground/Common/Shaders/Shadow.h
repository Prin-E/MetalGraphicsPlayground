//
//  Shadow.h
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 16/07/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#ifndef Shadow_h
#define Shadow_h

float get_shadow_lit(texture2d<float> shadow_map,
                     constant light_t &light,
                     constant light_global_t &light_global,
                     float4 world_pos);

#endif /* Shadow_h */
