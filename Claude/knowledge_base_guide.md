# Knowledge Base Guide

## Purpose and Structure

This knowledge base exists as an AI memory system to maintain deep understanding of the project across conversations. It is organized into focused domain files under Meta/Knowledge, with each file serving a specific role:

1. Core Domain Files:
   - actors_and_concurrency.md: Actor model and concurrency patterns
   - database_patterns.md: GRDB integration and database architecture
   - navigation_gestures.md: SwiftUI/UIKit navigation handling
   - performance_patterns.md: Performance optimization strategies
   - places_system.md: Places subsystem architecture
   - sampling_and_recording.md: Core recording system
   - swiftui_patterns.md: SwiftUI architecture and patterns
   - timeline_model.md: Timeline data model and processing

2. Support Files:
   - knowledge_base_guide.md (this file): Guide to knowledge base structure
   - workflow.md: Development standards and patterns
   - filesystem.md: Project structure and organization

## Usage Principles

1. Knowledge Evolution
   - Structure follows understanding, not predefined categories
   - Maintain both high-level concepts and crucial details
   - Include concrete code examples of key patterns
   - Update aggressively as new insights emerge
   - Keep uncertainties explicit
   - Track confidence levels in explanations

2. Evidence Sourcing  
   - Use dev logs (in Meta/Dev Logs) as evidence for knowledge
   - Note which understanding comes from which work
   - Track how confidence grows through implementation
   - Flag conflicts between theory and practice
   - Include paths to example implementations

3. Active Maintenance
   - Review relevant sections during task work
   - Update based on new evidence and insights
   - Add clear code examples of patterns
   - Refine structure as understanding deepens
   - Remove outdated content
   - Consolidate related concepts

4. Effective Learning
   - Focus on relationships between concepts
   - Maintain context across conversations
   - Build from concrete examples to principles
   - Keep practical utility as primary goal
   - Surface key insights in main sections

## Role in Development

This knowledge base is not documentation for humans - it's an AI memory system for maintaining deep project understanding. Key usage patterns:

1. Task Preparation
   - Review relevant knowledge sections
   - Note uncertainties needing investigation
   - Identify connected concepts
   - Reference example implementations
   - Note required source files

2. Work Documentation
   - Record concrete work in Meta/Dev Logs
   - Extract key insights to knowledge files
   - Update understanding based on evidence
   - Document important code patterns
   - Track confidence evolution

3. Knowledge Application
   - Reference specific sections when explaining
   - Note confidence levels in responses
   - Ground recommendations in examples
   - Surface relevant uncertainties
   - Be explicit about needed context

4. Understanding Evolution
   - Refactor structure as patterns emerge
   - Add clear code examples
   - Consolidate related knowledge
   - Prune outdated content
   - Strengthen relationship mapping

The goal is continuous refinement of understanding while maintaining clear confidence levels and evidence chains. The system should evolve naturally to best serve ongoing development work.

## Content Guidelines

Knowledge files should include:

1. Code Examples
   - Concrete implementations of patterns
   - Common usage examples
   - Edge case handling
   - File paths to real examples
   - Key method signatures

2. Pattern Documentation  
   - Clear explanation of purpose
   - When to use each approach
   - Common pitfalls
   - Performance implications
   - Actor isolation impact

3. Architectural Context
   - System relationships
   - Dependency flows
   - State management
   - Error handling
   - Background behavior

4. Evolution Notes
   - Why patterns exist
   - Alternative approaches considered
   - Known limitations
   - Future enhancement paths
   - Migration strategies

## Cross-File Relationships

Knowledge in this system is inherently interconnected. Key relationships include:

1. Timeline Processing Chain
   - timeline_model.md: Core data structures
   - sampling_and_recording.md: Sample generation
   - performance_patterns.md: Optimization strategies
   - actors_and_concurrency.md: Processing isolation

2. UI Architecture
   - swiftui_patterns.md: Core UI patterns
   - navigation_gestures.md: Navigation handling
   - timeline_model.md: Data representation

3. Data Management
   - database_patterns.md: Storage patterns
   - places_system.md: Place management
   - performance_patterns.md: Query optimization

Understanding these relationships helps maintain coherent knowledge across the system.