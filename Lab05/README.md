### Lab05 - matrix multiplication

The computation in a systolic array is performed in a pipelined fashion, with data flowing through the array from one PE to the next. 

Each PE computes a partial result based on the data it receives from its upstream neighbors, stores the result internally, and passes it downstream to the next PE. 

This process continues until the final result is computed by the last PE in the array.

Using serial input/output and control SRAM appropriately can reduce the total cycle effectively.


