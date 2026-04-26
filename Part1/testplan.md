# **TEST PLAN (AHB3-Lite Memory Slave Verification Plan)**

### 

### Overview



This document defines the verification plan for the AHB3-Lite memory slave. The goal is to validate correct functionality for:



* Transfer types (HTRANS)
* Burst types (HBURST)
* Transfer sizes (HSIZE)
* Read/Write correctness
* Address generation (INCR \& WRAP)
* Wait-state handling
* RAW contention behavior

### 

### Test Scenarios (Directed)

* ##### Test 1: SINGLE WRITE (BYTE)



**Stimulus:**



HTRANS = NONSEQ

HBURST = SINGLE

HSIZE  = BYTE

HWRITE = 1

HADDR  = 0x00000010

HWDATA = 0xAA



**Expected:**



Only lowest byte updated

Memory\[0x10] = 0xXX XX XX AA

HREADYOUT    = 1

No other bytes modified



* ##### Test 2: SINGLE WRITE (HALFWORD)



**Stimulus:**



HSIZE  = HALFWORD

HADDR  = 0x00000072

HWDATA = 0xBBBB



**Expected:**



Lower 2 bytes updated

Memory\[0x72] = 0xXX XX BB BB

HREADYOUT    = 1

No other bytes modified



* ##### Test 3: SINGLE WRITE (WORD)



**Stimulus:**



HSIZE  = WORD

HADDR  = 0x00000064

HWDATA = 0xDEADBEEF



**Expected:**



Full word written

Memory\[0x64] = 0xDEADBEEF

HREADYOUT    = 1

No other bytes modified



* ##### Test 4: SINGLE READ (BYTE)



**Stimulus:**



Perform read after write



**Expected:**



HRDATA returns correct value based on size

No corruption of adjacent bytes



* ##### Test 5: SINGLE READ (HALFWORD)



**Stimulus:**



Perform read after write



**Expected:**



HRDATA returns correct value based on size

No corruption of adjacent bytes



* ##### Test 6: SINGLE READ (WORD)



**Stimulus:**



Perform read after write



**Expected:**



HRDATA returns correct value based on size

No corruption of adjacent bytes



* ##### Test 7: RAW - SAME ADDRESS (Contention Case)



**Stimulus:**



Write to address 0x10.

Immediately read from same address



**Expected:**



contention = 1

HRDATA     = dout\_local

Read returns newly written value



* ##### Test 8: INCR4 BURST WRITE + READBACK



**Stimulus:**



HBURST = INCR4



Sequential writes to:



0x10, 0x14, 0x18, 0x1c



**Expected:**



Addresses increment by HSIZE

All values stored correctly

Readback matches written data



* ##### Test 9: INCR8 BURST



**Stimulus:**



HBURST = INCR8



**Expected:**



Address increments by HSIZE

No wrap occurs



* ##### Test 10: INCR16 BURST



**Stimulus:**



HBURST = INCR16



**Expected:**



Address increments by HSIZE

No wrap occurs

No address discontinuity



* ##### Test 11: WRAP4 BURST



**Stimulus:**



HBURST = WRAP4

Start at 0x0c (for word)



**Expected:**



Address Sequence (depending on HSIZE)

0x0C -> 0x10 -> 0x14 -> 0x0C



Address wraps correctly within 4-beat boundary

No overflow outside boundary



* ##### Test 12: WRAP8 BURST



**Stimulus:**



HBURST = WRAP8



**Expected:**



Address wraps within correctly 8-beat region

No overflow outside boundary





* ##### Test 13: HTRANS = IDLE



**Stimulus:**



HTRANS = IDLE



**Expected:**



we = 0

No memory access

No change in memory



* ##### Test 14: Back-to-Back Transfers



**Stimulus:**



Continuous transfers without IDLE

Alternating read/write operations



**Expected:**



No data loss

Pipeline works correctly

All writes/read valid



* ##### Test 15: Wait-State Insertion (HREADY = 0)



**Stimulus:**



Force HREADY = 0 during transfer



**Expected:**



Address and control signals held constant

No new transfer issued

Transfer resumes when HREADY = 1



### Test Scenario (Random)

* ##### Test 16: Random Transfers



**Stimulus:**



Random test (10,000 transactions)



**Expected:**



Completes with zero errors



### Cover Properties Goals

* ##### CP1: HREADY = 0 for 3+ consecutive cycles



**Scenerio:**



* Drive HREADY = 0 continuously for 3+ clock cycles
* Keep HSEL asserted during stall



**Expected Behavior:**



* No state corruption in memory
* No unintended write operations during stall
* HRDATA remains stable
* Transfer resumes correctly after HREADY returns high



* ##### CP2: WRAP4 burst with actual wrap-around



**Scenario:**



* Configure HBURST = WRAP4
* Start address aligned near a wrap boundary
* Perform 4 consecutive transfers



**Expected Behavior:**



* Address increments until boundary is reached
* Then wraps back to lower boundary region
* No illegal address generation



* ##### CP3: Write immediately followed by read to same address



**Scenario:**



* Perform a write to address A
* Immediately issue a read to same address in next cycle



**Expected Behavior:**



* HRDATA reflects updated value
* No mismatch between written and read data



* ##### CP4: HRESP = ERROR generation



**Scenario:**



* Attempt access that would trigger error condition



**Expected Behavior:**



* HRESP = ERROR observed



* ##### CP5: Back-to-back NONSEQ with no IDLE



**Scenario:**



* Issue continuous transactions
* No IDLE cycles between transfers



**Expected Behavior:**



* Correct address progression per burst rules
* Proper interpretation of NONSEQ only at start
* SEQ transfers maintain burst continuity
* No transaction drop or protocol violation



### Functional Coverage Goals



* ##### CP1: HTRANS Coverage



**Goal:** Hit all transfer types



* ##### CP2: HBURST Coverage



**Goal:** Exercise all burst types used in design.



* ##### CP3: HSIZE Coverage



**Goal:** Exercise all transfer sizes.



* ##### CP4: HWRITE Coverage



**Goal:** Ensure both read and write paths are exercised.



* ##### CP5: HREADY = 0 observed



**Goal:** Ensure stall behavior is exercised.



* ##### CP6: HRESP = ERROR observed



**Goal:** Ensure error response is exercised.



* ##### CP7: Address space split into 4 bins



**Goal:** Ensure full memory address space is exercised.



### Cross Coverage Test Intent



* ##### Cross 1: HBURST × HWRITE



**Scenario:**



* Burst reads
* Burst writes
* Mixed burst operations



* ##### Cross 2: HSIZE × HWRITE



**Scenario:**



* Different transfer sizes for read and write
* Ensure byte-enable correctness across sizes



* ##### Cross 3: HTRANS × HREADY



**Scenario:**



* Stall inserted mid-burst
* Resume transfer after stall



### Pass Criteria

* All directed tests pass
* No scoreboard mismatches
* All coverage points hit
* Random test (10,000 transactions) completes with zero errors



