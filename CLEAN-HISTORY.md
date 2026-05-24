- # Clean Git History
  
Create a clean branch from `main` with a logical commit progression for SDK example implementations.  
- ## Purpose
  
  When you've built an example application incrementally on a feature branch, this skill helps you create a clean, reviewable commit history that tells a learning story. Each commit should be independently reviewable and demonstrate a clear progression from foundation to production-ready application.  
- ## When to Use
- After completing an example implementation on a feature branch
- Before creating a PR for an example or tutorial application
- When you want to demonstrate a step-by-step learning journey
- To make code review easier by breaking down changes into logical chunks
- ## Prerequisites
  
	1. **Completed implementation**: The feature branch has a working implementation
	2. **Main branch**: A clean `main` branch to base the new branch on
	3. **Commit plan**: A clear plan for how to break down the changes (see structure below)

- ## Commit Structure Planning
  collapsed:: true
  
  Before starting, create a plan with 8-12 logical commits that follow this progression:  
  
	1. **Foundation** (1-2 commits): Build system, project structure, vendor dependencies
	2. **Data model** (1 commit): Core data structures with serialization and tests
	3. **Backend integration** (2-4 commits): Ditto FFI, local database, P2P sync, cloud sync

	- Break complex integrations into sub-commits (e.g., CBOR encoding as separate commit)
		4. **UI layer** (1-2 commits): Rendering backend, basic UI, event handling
		5. **Feature completion** (1-2 commits): CRUD operations, real-time updates, presence viewer
		6. **Configuration** (1 commit): Runtime configuration, environment variables
		7. **Cross-platform** (0-2 commits): WASM build, mobile support, platform-specific renderers
		8. **Documentation** (1 commit): Developer guides, testing scenarios, troubleshooting

- ### Marking Key Achievements
  
  Use ⭐ to mark commits that represent significant technical challenges or learning moments (e.g., implementing a CBOR encoder, solving a complex FFI boundary issue).  
- ## Implementation Process
- ### Step 1: Create New Branch from Main
  
  ```bash
  git checkout main
  git pull origin main
  git checkout -b <new-branch-name>
  ```
  
  Branch naming convention:  
- `feature/<example-name>-<language>` (e.g., `feature/carsapp-cpp-example`)
- `example/<name>-<language>` (e.g., `example/carsapp-rust`)
- ### Step 2: For Each Commit in the Plan
- #### A. Extract Files from Source Branch
  
  Use one of these methods:  
  
  **Method 1: Show specific files**  
  ```bash
  git show <source-branch>:path/to/file > path/to/file
  ```
  
  **Method 2: Create and apply patch**  
  ```bash
  git diff main...<source-branch> -- <file1> <file2> ... > temp.patch
  git apply temp.patch
  ```
  
  **Method 3: Cherry-pick and modify**  
  ```bash
  # Only if the original commits align with planned commits
  git cherry-pick -n <commit-sha>
  git reset HEAD <files-to-exclude>
  git checkout -- <files-to-exclude>
  ```
- #### B. Stage Only Commit-Specific Files
  
  ```bash
  git add <files-for-this-commit>
  ```
  
  **Important**: Only stage files specified in the commit plan. Use `git status` to verify.  
- #### C. Create Descriptive Commit
  
  ```bash
  git commit -m "<Title from plan>
  
  <Detailed description explaining what this commit adds and why>
  
  Files:
  - List of key files added/modified
  - Group by purpose (e.g., 'Core logic', 'Tests', 'Build system')
  "
  ```
- ### Step 3: Verification Points
  
  Test builds and functionality at key milestones:  
- **After data model commit**: Unit tests should pass
- **After backend integration**: Integration tests should pass
- **After UI layer**: Application should run (may need dependencies built)
- **After cross-platform**: Platform-specific builds should succeed
  
  Example verification commands:  
  ```bash
  make test                    # Run unit tests
  make test-integration        # Run integration tests
  make run                     # Run the application
  make build-wasm             # Cross-platform builds
  ```
- ### Step 4: Final Review
  
  ```bash
  # View commit history
  git log --oneline <new-branch> --not main
  
  # Should show your planned number of commits (e.g., 10 commits)
  
  # Review each commit
  git show <commit-sha>
  
  # Check that no unintended files were included
  git diff main...<new-branch>
  ```
- ## Commit Message Best Practices
- ### Title (First Line)
- Use imperative mood: "Add X", "Implement Y", "Enable Z"
- Be specific: "Add CBOR encoder for DQL queries" not "Update Ditto manager"
- 50-72 characters max
- ### Body (Subsequent Lines)
- Explain **what** and **why**, not how (code shows how)
- Describe the user-facing or developer-facing impact
- Note any technical challenges solved
- Reference related docs, ADRs, or Linear issues if applicable
- ### File List (Optional)
  Helpful for large commits:  
  ```
  Files:
  - src/core/* - Core implementation
  - tests/* - Unit and integration tests
  - Makefile - Build system updates
  ```
- ## Key Considerations
- ### Makefile Evolution
  The Makefile will likely be updated in multiple commits. Each update should only include:  
- Targets relevant to that commit's functionality
- Dependencies needed for those targets
- No future targets that aren't used yet
- ### Vendor Dependencies
  Include all vendored third-party code in the foundation commit:  
- Complete directories (don't cherry-pick files)
- Include any LICENSE or README files
- Note versions in commit message if known
- ### Build Verification Requirements
  Before marking a commit as "done", verify:  
- Code compiles (at verification points)
- No unrelated files included
- Commit message is clear and accurate
- Changes align with commit plan
- ### WASM and Cross-Platform Files
  Group platform-specific files logically:  
- Renderer implementations in UI layer commits
- WASM entry points in cross-platform commit
- HTML/JS wrappers with WASM integration
- Platform-specific build configs with their implementations
- ## Common Pitfalls
  
  ❌ **Don't:**  
- Include files from future commits "while you're at it"
- Skip verification points
- Write vague commit messages like "WIP" or "updates"
- Cherry-pick commits with merge conflicts
- Include generated files or build artifacts
  
  ✅ **Do:**  
- Follow the commit plan strictly
- Test at each verification point
- Write clear, descriptive commit messages
- Review `git status` before each commit
- Keep related changes together in one commit
- ## Example: Cars App C Implementation
  
  See the plan file at `.claude/plans/async-splashing-scott.md` for a complete example of this skill applied to the C Cars App implementation.  
  
  Key highlights from that example:  
- 10 logical commits from foundation to documentation
- Commit 3b marked with ⭐ for CBOR encoder (hardest technical challenge)
- Clear progression: build system → data model → Ditto integration → UI → WASM → docs
- Verification points after commits 2, 3, 4, 8
- ## SDK-Specific Adaptations
- ### C++ (Next Implementation)
- Adjust for C++ idioms (classes, RAII, smart pointers)
- May need commits for: CMake build system, C++ API wrappers, exception handling
- Consider: header/source file splits, namespace organization
- ### Rust (Future Implementation)
- Adjust for Rust idioms (ownership, lifetimes, error handling)
- May need commits for: Cargo.toml setup, trait implementations, async runtime
- Consider: module organization, pub/pub(crate) visibility
- ### Other Languages
  Adapt the commit structure to language-specific patterns while maintaining the overall progression: foundation → data model → backend → UI → polish → cross-platform → docs.  
- ## Success Criteria
  
  A successful clean git history has:  
- ✅ 8-12 logical, reviewable commits
- ✅ Each commit builds successfully (at verification points)
- ✅ Clear progression that tells a learning story
- ✅ Descriptive commit messages with context
- ✅ No unrelated or future changes in early commits
- ✅ Tests pass at appropriate milestones
- ✅ Documentation as final commit(s)
- ## Related Resources
- Git documentation: https://git-scm.com/doc
- Conventional Commits: https://www.conventionalcommits.org/
- Ditto SDLC guidelines: `.claude/rules/sdlc.md`
