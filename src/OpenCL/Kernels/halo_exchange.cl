// Write the recieved buffer to the array
// Halo order in the buffer: top|bottom|left|right where top and bottom contain the corners and thus have two more points along i each
void exchange_2_halo_write(
    __global float2 *array,
    __global float *buffer,
    const unsigned int im,
    const unsigned int jm,
    const unsigned int km
    ) {
    const unsigned int v_dim = 2;
    const unsigned int buf_sz = v_dim * 4 * (im+1) * km;
    const unsigned int v_limit = buf_sz / v_dim;
    const unsigned int tp_bound = (buf_sz / (4 * v_dim)) + 2;
    const unsigned int bl_bound = (buf_sz / (2 * v_dim)) + 3;
    const unsigned int lr_bound = (3 * buf_sz / (4 * v_dim)) + 2;
    float *vector[v_dim];
    unsigned int i, i_off, vec_off;
    
    vector[0] = array.s0;
    vector[1] = array.s1;
    
    // Iterate along buffer
    for (i = 0; i < buf_sz; i++) {
        // Which vector component, ie along v_dim
        vec_off = i / v_limit;
        // Offset for each vector
        i_off = i - (vec_off * v_limit);
        // top halo
        if (i_off < tp_bound) {
            // Can't simplfify im because it relies on integer division!
            vector[vec_off][(i_off%im) + (i_off/im)*(im*jm)] = buffer[i];
        }
        // bottom halo
        if (i_off >= tp_bound && i_off < bl_bound) {
            // Can't simplfify im because it relies on integer division!
            vector[vec_off][((i_off-tp_bound)%im) + im*(jm-1) + ((i_off-tp_bound)/im)*(im*jm)] = buffer[i];
        }
        // left halo
        if (i_off >= bl_bound && i_off < lr_bound) {
            vector[vec_off][2*im*((i_off-bl_bound)/(jm-2)) + ((i_off-bl_bound)+1)*im] = buffer[i];
        }
        // right halo
        if (i_off >= lr_bound) {
            vector[vec_off][2*im*((i_off-lr_bound)/(jm-2)) + ((i_off-lr_bound)+1)*im + (im-1)] = buffer[i];
        }
    }
}

// From the array to the in buffers
void exchange_2_halo_out(
    __global float2 *array,
    __global float2 *t_in,
    __global float2 *r_in,
    __global float2 *b_in,
    __global float2 *l_in,
    const unsigned int im,
    const unsigned int jm,
    const unsigned int km,
    const unsigned int h_h
    ) {
    int i, j, k;
    int lcount = 0, rcount = 0;
    //t_in and b_in are contiguous on i and j, but not on k
    for (k = 0; k < km; k++) {
        memcpy(t_in + k * im * h_h, array + k * im * jm, h_h * im * sizeof(*array));
        memcpy(b_in + k * im * h_h, array + (k + 1) * im * jm - (h_h * im), h_h * im * sizeof(*array));
        
        // l_out and r_out are not contiguous
        for (i = 0; i < im; i++) {
            for (j = 0; j < jm; j++) {
                // Left side of the array
                if (i < h_h) {
                    l_in[lcount] = array[k * im * jm + j * im + i];
                    lcount++;
                }
                // Right side of the array
                if (i > im - h_h - 1) {
                    r_in[rcount] = array[k * im * jm + j * im + i];
                    rcount++;
                }
            }
        }
    }
}