Feature: Typed text

    For a reader of the course who edits a section that another device edits
    too.

    The screen shows the current row with typed changes over it. An act that
    leaves the block list unchanged records its changed blocks and atoms as
    typed. The host decides when to save them. An act that changes the block
    list saves the displayed section at once. Every save clears the typed
    changes and makes the saved section the current row.

    When a row lands, the core calls the merge function that the port supplies.
  The base is the current row. The local is the displayed section. The remote
  is the row that landed. The screen shows the section that the merge function
  returns. The remote becomes the current row. Differences between the result
  and the current row remain typed.

  The merge function in these scenarios keeps a local block or atom when it
  differs from the base. Otherwise, it takes the remote block or atom.

  # ── Typing ─────────────────────────────────────────────────────────────

  Scenario: The editor records typed text for the block
    Given a section
      | block | text                                          |
      | a     | A set is closed║ when its complement is open. |
      | b     | Both the empty set and X are closed.          |
    When the person types "A set is closed in X║ when its complement is open."
    Then the typed text is
      | block | text                                              |
      | a     | A set is closed in X when its complement is open. |

  Scenario: Typing leaves the row unchanged
    Given a section
      | block | text                                          |
      | a     | A set is closed║ when its complement is open. |
      | b     | Both the empty set and X are closed.          |
    When the person types "A set is closed in X║ when its complement is open."
    Then the row is
      | block | text                                         |
      | a     | A set is closed when its complement is open. |
      | b     | Both the empty set and X are closed.         |

  Scenario: Typing does not reach the port
    Given a section
      | block | text                                          |
      | a     | A set is closed║ when its complement is open. |
      | b     | Both the empty set and X are closed.          |
    When the person types "A set is closed in X║ when its complement is open."
    Then the port receives nothing

  Scenario: Editing an atom records typed text for that atom
    Given a section
      | block | text                                   |
      | a     | A set {{a8f1}} is open by definition.║ |
      | b     | The union of open sets is open.        |
    And its atoms
      | atom | type | source     |
      | a8f1 | math | U \in \tau |
    When the person edits atom "a8f1" to read "U \subseteq X"
    Then the typed text is
      | atom | type | source        |
      | a8f1 | math | U \subseteq X |
    And the port receives nothing

  Scenario: Placing an atom records typed text for that atom
    Given a section
      | block | text                                |
      | a     | An open cover of the unit interval: |
      | b     | :: {{f2}}║                          |
    And its atoms
      | atom | type  | source | param |
      | f2   | image | r42    |       |
    When the person places atom "f2" at "width=50%"
    Then the typed text is
      | atom | type  | source | param     |
      | f2   | image | r42    | width=50% |
    And the port receives nothing

  Scenario: Changing a mark records typed text for the block
    Given a section
      | block | text                              |
      | a     | Every {open ball} is an open set. |
      | b     | The union of open sets is open.   |
    When the person presses bold
    Then the typed text is
      | block | text                                |
      | a     | Every **open ball** is an open set. |
    And the port receives nothing

  Scenario: Changing a link records typed text for the block
    Given a section
      | block | text                                         |
      | a     | Every {open ball} is open in a metric space. |
      | b     | The union of open sets is open.              |
    When the person links the selection to "/open-balls"
    Then the typed text is
      | block | text                                                      |
      | a     | Every [open ball](/open-balls) is open in a metric space. |
    And the port receives nothing

  Scenario: Pasting within a block records typed text for the block
    Given a section
      | block | text                                               |
      | a     | Every open cover has a {countable} subcover.       |
      | b     | Every closed subset of a compact space is compact. |
    When the person pastes "finite"
    Then the typed text is
      | block | text                                    |
      | a     | Every open cover has a finite subcover. |
    And the port receives nothing

  # ── Rows landing ───────────────────────────────────────────────────────

  Scenario: The merge function receives the base, local and remote sections
    Given a section
      | block | text                                          |
      | a     | A set║ is closed when its complement is open. |
      | b     | Both the empty set and X are closed.          |
    When the person types "A set A║ is closed when its complement is open."
    And a row lands
      | block | text                                               |
      | a     | A set is closed when its complement X \ A is open. |
      | b     | Both the empty set and X are closed.               |
    Then the port's merge function receives the base
      | block | text                                         |
      | a     | A set is closed when its complement is open. |
      | b     | Both the empty set and X are closed.         |
    And it receives the local
      | block | text                                           |
      | a     | A set A is closed when its complement is open. |
      | b     | Both the empty set and X are closed.           |
    And it receives the remote
      | block | text                                               |
      | a     | A set is closed when its complement X \ A is open. |
      | b     | Both the empty set and X are closed.               |

  Scenario: The section shows the merge function's result
    Given a section
      | block | text                                                             |
      | a     | A space is compact when every open cover║ has a finite subcover. |
      | b     | Every closed subset of a compact space is compact.               |
    When the person types "A space is compact when every open cover of it║ has a finite subcover."
    And a row lands
      | block | text                                                           |
      | a     | A space is compact when each open cover has a finite subcover. |
      | b     | Every closed subset of a compact space is compact too.         |
    Then the section shows
      | block | text                                                                   |
      | a     | A space is compact when every open cover of it║ has a finite subcover. |
      | b     | Every closed subset of a compact space is compact too.                 |

  Scenario: The landed row becomes the new base
    Given a section
      | block | text                                                             |
      | a     | A space is compact when every open cover║ has a finite subcover. |
      | b     | Every closed subset of a compact space is compact.               |
    When the person types "A space is compact when every open cover of it║ has a finite subcover."
    And a row lands
      | block | text                                                           |
      | a     | A space is compact when each open cover has a finite subcover. |
      | b     | Every closed subset of a compact space is compact too.         |
    Then the row is
      | block | text                                                           |
      | a     | A space is compact when each open cover has a finite subcover. |
      | b     | Every closed subset of a compact space is compact too.         |

  Scenario: The editor clears typed text that the landed row already contains
    Given a section
      | block | text                                          |
      | a     | A set is closed║ when its complement is open. |
      | b     | Both the empty set and X are closed.          |
    When the person types "A set is closed in X║ when its complement is open."
    And a row lands
      | block | text                                              |
      | a     | A set is closed in X when its complement is open. |
      | b     | Both the empty set and X are closed.              |
    Then no typed text is left

  Scenario: The section shows a landed row when no typed text exists
    Given a section
      | block | text                                                                           |
      | a     | A map f from X to Y is continuous when the preimage of every open set is open. |
      | b     | Every constant map is continuous.                                              |
      | c     | The identity map on X is continuous.                                           |
    When a row lands
      | block | text                                                                           |
      | a     | A map f from X to Y is continuous when the preimage of every open set is open. |
      | b     | Every constant map is continuous, whatever the topologies.                     |
      | c     | The identity map on X is continuous.                                           |
    Then the section shows
      | block | text                                                                           |
      | a     | A map f from X to Y is continuous when the preimage of every open set is open. |
      | b     | Every constant map is continuous, whatever the topologies.                     |
      | c     | The identity map on X is continuous.                                           |

  Scenario: A landed row removes a block with no typed text
    Given a section
      | block | text                             |
      | a     | Every metric space is Hausdorff. |
      | b     | Every Hausdorff space is T1.     |
      | c     | A finite T1 space is discrete.   |
    When a row lands
      | block | text                             |
      | a     | Every metric space is Hausdorff. |
      | c     | A finite T1 space is discrete.   |
    Then the section shows
      | block | text                             |
      | a     | Every metric space is Hausdorff. |
      | c     | A finite T1 space is discrete.   |

  Scenario: The merge function keeps a typed block that the row removes
    Given a section
      | block | text                             |
      | a     | Every metric space is Hausdorff. |
      | b     | Every Hausdorff space is║ T1.    |
      | c     | A finite T1 space is discrete.   |
    When the person types "Every Hausdorff space is also║ T1."
    And a row lands
      | block | text                             |
      | a     | Every metric space is Hausdorff. |
      | c     | A finite T1 space is discrete.   |
    Then the section shows
      | block | text                               |
      | a     | Every metric space is Hausdorff.   |
      | b     | Every Hausdorff space is also║ T1. |
      | c     | A finite T1 space is discrete.     |

  Scenario: The merge function receives an atom's typed source in the local
    Given a section
      | block | text                                        |
      | a     | The set {{a8f1}} is open for every open V.║ |
      | b     | So f is continuous.                         |
    And its atoms
      | atom | type | source    |
      | a8f1 | math | f^{-1}(V) |
    When the person edits atom "a8f1" to read "f^{-1}(V) \in \tau_X"
    And a row lands
      | block | text                                            |
      | a     | The set {{a8f1}} is open in X for every open V. |
      | b     | So f is continuous.                             |
    Then the port's merge function receives the local
      | block | text                                       |
      | a     | The set {{a8f1}} is open for every open V. |
      | b     | So f is continuous.                        |
    And its atoms
      | atom | type | source               |
      | a8f1 | math | f^{-1}(V) \in \tau_X |

  # ── Saving ─────────────────────────────────────────────────────────────

  Scenario: The host saves the displayed section through the port
    Given a section
      | block | text                                                       |
      | a     | A map║ is continuous when preimages of open sets are open. |
      | b     | The set {{a8f1}} is open for every open V.                 |
    And its atoms
      | atom | type | source    |
      | a8f1 | math | f^{-1}(V) |
    When the person types "A map f║ is continuous when preimages of open sets are open."
    And the person edits atom "a8f1" to read "f^{-1}(V) \in \tau_X"
    And the host saves
    Then the port receives
      | block | text                                                        |
      | a     | A map f is continuous when preimages of open sets are open. |
      | b     | The set {{a8f1}} is open for every open V.                  |
    And its atoms
      | atom | type | source               |
      | a8f1 | math | f^{-1}(V) \in \tau_X |

  Scenario: A save clears the typed text
    Given a section
      | block | text                                                  |
      | a     | Every compact subset of a Hausdorff space║ is closed. |
      | b     | A closed subset of a compact space is compact.        |
    When the person types "Every compact subset of a Hausdorff space X║ is closed."
    And the host saves
    Then no typed text is left

  Scenario: A save replaces the row with the saved section
    Given a section
      | block | text                                                  |
      | a     | Every compact subset of a Hausdorff space║ is closed. |
      | b     | A closed subset of a compact space is compact.        |
    When the person types "Every compact subset of a Hausdorff space X║ is closed."
    And the host saves
    Then the row is
      | block | text                                                   |
      | a     | Every compact subset of a Hausdorff space X is closed. |
      | b     | A closed subset of a compact space is compact.         |

  Scenario: The merge function receives the saved section as its next base
    Given a section
      | block | text                                                  |
      | a     | Every compact subset of a Hausdorff space║ is closed. |
      | b     | A closed subset of a compact space is compact.        |
    When the person types "Every compact subset of a Hausdorff space X║ is closed."
    And the host saves
    And a row lands
      | block | text                                                  |
      | a     | Each compact subset of a Hausdorff space X is closed. |
      | b     | A closed subset of a compact space is compact.        |
    Then the port's merge function receives the base
      | block | text                                                   |
      | a     | Every compact subset of a Hausdorff space X is closed. |
      | b     | A closed subset of a compact space is compact.         |

  Scenario: A landed row replaces a saved block
    Given a section
      | block | text                                                  |
      | a     | Every compact subset of a Hausdorff space║ is closed. |
      | b     | A closed subset of a compact space is compact.        |
    When the person types "Every compact subset of a Hausdorff space X║ is closed."
    And the host saves
    And a row lands
      | block | text                                                  |
      | a     | Each compact subset of a Hausdorff space X is closed. |
      | b     | A closed subset of a compact space is compact.        |
    Then the section shows
      | block | text                                                   |
      | a     | Each compact subset of a Hausdorff space X║ is closed. |
      | b     | A closed subset of a compact space is compact.         |

  # ── Acts that change the list save at once ─────────────────────────────

  Scenario: A join saves at once
    Given a section
      | block | text                                                               |
      | a     | A topology on a set X is a collection of subsets called open sets. |
      | b     | ║The empty set and X itself are open.                              |
    When the person presses backspace
    Then the port receives
      | block | text                                                                                                    |
      | a     | A topology on a set X is a collection of subsets called open sets. The empty set and X itself are open. |

  Scenario: A split saves at once
    Given a section
      | block | text                                                                            |
      | a     | A map f from X to Y is continuous when║ the preimage of every open set is open. |
      | b     | Every constant map is continuous.                                               |
    When the person presses enter
    Then the port receives
      | block | text                                    |
      | a     | A map f from X to Y is continuous when  |
      | c     | the preimage of every open set is open. |
      | b     | Every constant map is continuous.       |

  Scenario: A move saves at once
    Given a section
      | block | text                                      |
      | a     | Open sets are closed under unions.        |
      | b     | ║A topology is a collection of open sets. |
    When the person moves the block up
    Then the port receives
      | block | text                                     |
      | b     | A topology is a collection of open sets. |
      | a     | Open sets are closed under unions.       |

  Scenario: A removal saves at once
    Given a section
      | block | text                                                            |
      | a     | A set is open when it is a neighbourhood of each of its points. |
      | b     | ║                                                               |
      | c     | Every open ball is an open set.                                 |
    When the person presses backspace
    Then the port receives
      | block | text                                                            |
      | a     | A set is open when it is a neighbourhood of each of its points. |
      | c     | Every open ball is an open set.                                 |

  Scenario: A paste of several lines saves at once
    Given a section
      | block | text                                                |
      | a     | A topology on X has three axioms: ║and that is all. |
    When the person pastes "the empty set and X are open.\nAny union of open sets is open.\nAny finite intersection of open sets is open,"
    Then the port receives
      | block | text                                                            |
      | a     | A topology on X has three axioms: the empty set and X are open. |
      | b     | Any union of open sets is open.                                 |
      | c     | Any finite intersection of open sets is open, and that is all.  |

  Scenario: A split sends the typed text of another block with it
    Given a section
      | block | text                                          |
      | a     | A set is closed║ when its complement is open. |
      | b     | Both the empty set and X are closed.          |
    When the person types "A set is closed in X║ when its complement is open."
    And the person clicks "Both the empty set║ and X are closed."
    And the person presses enter
    Then the port receives
      | block | text                                              |
      | a     | A set is closed in X when its complement is open. |
      | b     | Both the empty set                                |
      | c     | and X are closed.                                 |

  Scenario: A split clears the typed text of another block
    Given a section
      | block | text                                          |
      | a     | A set is closed║ when its complement is open. |
      | b     | Both the empty set and X are closed.          |
    When the person types "A set is closed in X║ when its complement is open."
    And the person clicks "Both the empty set║ and X are closed."
    And the person presses enter
    Then no typed text is left
