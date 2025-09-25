# AXI Bus Pipeline Circuit Design Guide

## Introduction

This document is designed to be read by AI for automatic code generation.

We will introduce the basic design techniques for pipeline operations required for AXI bus design in multiple parts.

As of July 2025, there are few design guides explaining the design rules for pipeline circuits and appropriate training data for AI learning. When debugging AXI bus circuits that should operate in pipeline mode, they are often converted to sequential operation. This is due to the lack of appropriate training data that explains the basic principles and analysis methods of pipeline circuits. We will introduce attempts to design AXI bus-connectable components by explaining design methods to AI.

## Document List

### [Part 1: Pipeline Operation Principles](part01_pipeline_principles.md)
 - Basic pipeline operations and Ready/Valid handshake mechanisms
 - Design methodology for pipeline circuits using inductive design

### [Part 2: Circuit for Inserting One Stage of FF into Ready Signal and Data](part02_pipeline_insert.md)
 - Circuit for inserting one stage of FF into Ready signal and data while maintaining basic pipeline rules for data and Ready
 - Optimization of pipeline insertion using exhaustive search method

### [Part 3: Testbench for Verifying Pipeline Operations](part03_pipeline_testbench.md)
 - Testbench for reliable verification of pipeline circuit operations
 - Avoiding delta delay issues and verifying pipeline operations

### [Part 4: Simulation of Pipeline AXI Read Address Channel with N-fold Payload Increase](part04_burst_read_pipeline.md)
 - Design and implementation of payload amplification pipeline
 - Implementation of burst read pipeline module and testbench

### [Part 5: Simulation of Pipeline AXI Write Data Channel with Payload Convergence](part05_burst_write_pipeline.md)
 - Design and implementation of pipeline with payload convergence
 - Implementation of burst write pipeline module and testbench
 - Simplification of pipeline design through essential element abstraction

### [Part 6: Implementation of Read/Write Pipeline with Integrated State Management](part06_burst_rw_pipeline.md)
 - Design and implementation of read/write integrated control pipeline
 - Priority control through common state machine
 - Implementation of burst read/write pipeline module and testbench
 - Optimization of state transitions using condition coverage and condition pruning methods

### [Part 7: AXI4 Specification Simple Dual Port RAM](part07_axi_simple_dual_port_ram.md)
 - Design and implementation of AXI4-compliant simple dual port RAM
 - Parallel processing through independent read/write pipelines
 - Support for three burst modes (FIXED, INCR, WRAP)
 - Hallucination, Potemkin understanding, and cognitive bias elimination
 - Micro debugging and spaghetti code conversion
 - Reset and restart method

### [Part 8: Essential Element Abstraction Design for AXI4 Bus Testbench](part08_axi4_bus_testbench_abstraction.md)
 - Abstraction and systematization of essential elements for AXI4 bus testbench
 - Definition of six basic elements (parameter setting, hardware control, test data generation/control, data verification, protocol verification, monitoring/logging)
 - Optimization of test patterns through weighted random generation
 - Establishment of comprehensive testbench design methodology

### [Part 9: Functional Classification of AXI4 Bus Testbench](part09_axi4_testbench_refactoring.md)
 - File splitting and generalization by function for code created in Part 8
 - Classification into five functional systems (common definition/parameter, test stimulus generation, verification/expected value generation, logging/monitoring, utility function)
 - Risk minimization through gradual file splitting implementation
 - Dependency management through include statements and simple structuring

### [Part 10: AXI4 Specification Simple Single Port RAM](part10_axi_simple_single_port_ram.md)
 - Design and implementation of AXI4-compliant simple single port RAM
 - Exclusive access control through read/write integrated control pipeline
 - Priority control through 5-stage state machine (IDLE, R_NLAST, R_LAST, W_NLAST, W_LAST)

### [Part 11: AXI4 Bus Testbench Refactoring](part11_axi4_testbench_refactoring.md)
 - **Extended Strobe Control**: Control of strobe generation strategy through parameters
 - **Advanced Random Generation**: Combination of weighted selection and strobe strategy
 - **Improved Test Coverage**: Testing of various strobe patterns
 - **Enhanced Implementation Maintainability**: Control of behavior through settings and strengthened error detection

### [Part 12: AXI4 SIZE and WRAP Specifications](part12_axi4_size_wrap_specification.md)
 - Detailed specifications of AXI4 protocol SIZE constraints and WRAP burst
 - Accurate explanation based on IHI0022B_AMBAaxi official specification
 - Implementation requirements for SIZE constraints (relationship between transfer size and bus width)
 - Details of WRAP burst address calculation and boundary constraints
 - Implementation considerations and explanation of test strategy (size_strategy)

### [Part 13: AXI4 Bus Testbench Byte Access Verification Function](part13_axi4_testbench_byte_access_verification.md)
 - Problems with conventional methods: Difficulty in detecting address calculation errors in both READ/WRITE
 - New verification method: Accurate confirmation through individual verification in byte units
 - Implementation of methods for more rigorous verification of address calculation accuracy

### Future Plans
- Part 14 and beyond: Bus width conversion and clock frequency conversion components (in preparation)

### Rule Collection
Rule collection for consistent document creation by AI

- [Rule 1. Sequence Chart Description](rule01_sequence_chart_rules.md)
- [Rule 2. Delta Delay Problem Avoidance](rule02_delta_delay_examples.md)

### Development and Debugging Methods

  - Incremental method
  - Binary search method
  - Random method
  - Exhaustive search method
  - Condition coverage method
  - Inductive method
  - Boundary condition method
  - Partial derivative investigation method
  - Condition pruning method
  - Reset and restart method
  - Micro debugging and spaghetti code conversion
  - Hallucination, Potemkin understanding, and cognitive bias elimination
  - Essential element abstraction
  - File splitting by functional classification
  - Gradual refactoring
  - Dependency management through include statements

## Document Creation Policy

This document records know-how for simplifying and streamlining hardware design for pipeline operations. It is created following these policies:

- **Simplicity**: Only the minimum necessary information is recorded
- **Conciseness**: Avoiding redundant explanations and expressing key points concisely
- **Understandability**: Clear descriptions that both humans and AI can understand
- **Practicality**: Practical content that can be used in actual design
- **Inheritance**: Passing on technology to future designers and AI
- **Internationalization**: International understanding through English comments and unified terminology

## Target Audience

- Hardware designers
- As training data for AI code generation
- Students and engineers learning AXI bus design
- Those who want to learn pipeline circuit design techniques
- Those who want to learn implementation of burst transfer and payload amplification pipelines

## Technology Stack

- SystemVerilog HDL
- AXI Bus Protocol
- Pipeline Design Techniques
- Ready/Valid Handshake
- Testbench Design

## License

This project is released under the [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0).

### License Features
- **Attribution**: Copyright notice and license information retention is mandatory
- **Commercial Use**: Permitted
- **Modification and Redistribution**: Permitted (license information retention required)
- **Patent Rights**: Explicit permission

### Requirements
- Retention of license and copyright notice
- Indication of changes (when modified)
- Retention of NOTICE file (if it exists)

For details, please refer to [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0).

## Contributing

Improvement suggestions and bug reports are welcome through GitHub Issues or Pull Requests.

---

*This document is designed to be used as training data for AI to learn hardware design.*
