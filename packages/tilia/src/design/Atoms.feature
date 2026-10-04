Feature: Live atoms

  For a reader of the course whose section holds formulas and figures.

  The host hands the editor its rules by name, and each atom names its rule.
  A rule decodes the param, gives a first value, loads the live atom, and
  draws it.

  The editor holds each atom as one object, with its rule, its text and its
  param. The object stays the same while its id stays in the section. A new
  text or a new param is written into it, and the param object is merged
  key by key. So a change reaches only what reads the part that changed.
  "The same object" in a scenario compares with the object the editor held
  before the first act.

  The editor holds one live atom for each atom id. The loader runs when
  the live atom is first drawn. It runs again when a value it read changes:
  the atom's text, or the record it loads. It then receives the previous
  live atom, so a new image can keep the old one on screen until it is
  ready. A new param is not read by the loader, so it runs no loader.

  The `math` rule's live atom is the atom object itself. The `image` rule's
  live atom is the image model: Loading, Missing, Downloading, Uploading or
  Ready. The image loader in these scenarios reads the records of the
  scenario. A record with its bytes on the device is Ready. A record without
  them is Downloading. A record still on its way leaves the previous value.
  An id with no record is Missing.

  # ── Rules ──────────────────────────────────────────────────────────────

  Scenario: A formula's live atom is its text
    Given a section
      | block | text                                  |
      | a     | A set {{a8f1}} is open by definition.║ |
    And its atoms
      | atom | rule | source     |
      | a8f1 | math | U \in \tau |
    Then the live atoms are
      | atom | live       |
      | a8f1 | U \in \tau |

  Scenario: An atom whose rule has no editor enters the box on a click
    Given a section
      | block | text                                  |
      | a     | A set {{a8f1}} is open by definition.║ |
    And its atoms
      | atom | rule | source     |
      | a8f1 | math | U \in \tau |
    When the person clicks atom "a8f1"
    Then the box holds atom "a8f1"
    And no editor is open

  Scenario: An atom whose rule has an editor opens it on a click
    Given a section
      | block | text                                |
      | a     | An open cover of the unit interval:║ |
      | b     | :: {{f2}}                           |
    And its atoms
      | atom | rule  | source |
      | f2   | image | r42    |
    And the records
      | record | title     | description                          | width | height | bytes  |
      | r42    | cover.png | Three open intervals cover [0, 1].   | 800   | 400    | device |
    When the person clicks atom "f2"
    Then the editor of atom "f2" is open
    And the box is closed

  Scenario: An atom whose rule the host does not give shows its source
    Given a section
      | block | text                                     |
      | a     | The proof is in {{q7}}.║                 |
    And its atoms
      | atom | rule | source           |
      | q7   | quiz | Is [0, 1] open?  |
    Then atom "q7" draws "Is [0, 1] open?"

  # ── Loading ────────────────────────────────────────────────────────────

  Scenario: An image whose record is on its way shows the first value
    Given a section
      | block | text                                |
      | a     | An open cover of the unit interval:║ |
      | b     | :: {{f2}}                           |
    And its atoms
      | atom | rule  | source |
      | f2   | image | r42    |
    And the records
      | record | title     | description                        | width | height | bytes   |
      | r42    | cover.png | Three open intervals cover [0, 1]. | 800   | 400    | on way  |
    Then the live atoms are
      | atom | live          |
      | f2   | Loading(r42)  |

  Scenario: An image with no record is missing
    Given a section
      | block | text                                |
      | a     | An open cover of the unit interval:║ |
      | b     | :: {{f2}}                           |
    And its atoms
      | atom | rule  | source |
      | f2   | image | r42    |
    Then the live atoms are
      | atom | live          |
      | f2   | Missing(r42)  |

  Scenario: An image whose bytes are on the device is ready
    Given a section
      | block | text                                |
      | a     | An open cover of the unit interval:║ |
      | b     | :: {{f2}}                           |
    And its atoms
      | atom | rule  | source |
      | f2   | image | r42    |
    And the records
      | record | title     | description                        | width | height | bytes  |
      | r42    | cover.png | Three open intervals cover [0, 1]. | 800   | 400    | device |
    Then the live atoms are
      | atom | live                    |
      | f2   | Ready(r42, 800 × 400)   |

  Scenario: An image whose bytes are not on the device is downloading
    Given a section
      | block | text                                |
      | a     | An open cover of the unit interval:║ |
      | b     | :: {{f2}}                           |
    And its atoms
      | atom | rule  | source |
      | f2   | image | r42    |
    And the records
      | record | title     | description                        | width | height | bytes  |
      | r42    | cover.png | Three open intervals cover [0, 1]. | 800   | 400    | remote |
    Then the live atoms are
      | atom | live                        |
      | f2   | Downloading(r42, 800 × 400) |

  Scenario: The live atom follows the record when its bytes arrive
    Given a section
      | block | text                                |
      | a     | An open cover of the unit interval:║ |
      | b     | :: {{f2}}                           |
    And its atoms
      | atom | rule  | source |
      | f2   | image | r42    |
    And the records
      | record | title     | description                        | width | height | bytes  |
      | r42    | cover.png | Three open intervals cover [0, 1]. | 800   | 400    | remote |
    When the bytes of record "r42" arrive
    Then the live atoms are
      | atom | live                    |
      | f2   | Ready(r42, 800 × 400)   |

  # ── When the loader runs ───────────────────────────────────────────────

  Scenario: The loader runs once for each atom
    Given a section
      | block | text                                |
      | a     | An open cover of the unit interval:║ |
      | b     | :: {{f2}}                           |
      | c     | A finite subcover: {{f3}}           |
    And its atoms
      | atom | rule  | source |
      | f2   | image | r42    |
      | f3   | image | r57    |
    And the records
      | record | title      | description                         | width | height | bytes  |
      | r42    | cover.png  | Three open intervals cover [0, 1].  | 800   | 400    | device |
      | r57    | finite.png | Two of the intervals cover [0, 1].  | 800   | 400    | device |
    When the person types "An open cover of the closed unit interval:║"
    Then the loader was called once for each atom
      | atom |
      | f2   |
      | f3   |

  Scenario: A new param calls no loader
    Given a section
      | block | text                                |
      | a     | An open cover of the unit interval: |
      | b     | :: {{f2}}║                          |
    And its atoms
      | atom | rule  | source |
      | f2   | image | r42    |
    And the records
      | record | title     | description                        | width | height | bytes  |
      | r42    | cover.png | Three open intervals cover [0, 1]. | 800   | 400    | device |
    When the person places atom "f2" at "width=50%"
    Then the loader was called once for each atom
      | atom |
      | f2   |

  Scenario: A new text runs the loader with the previous live atom
    Given a section
      | block | text                                |
      | a     | An open cover of the unit interval: |
      | b     | :: {{f2}}║                          |
    And its atoms
      | atom | rule  | source |
      | f2   | image | r42    |
    And the records
      | record | title      | description                        | width | height | bytes  |
      | r42    | cover.png  | Three open intervals cover [0, 1]. | 800   | 400    | device |
      | r57    | finite.png | Two of the intervals cover [0, 1]. | 600   | 300    | device |
    When the person edits atom "f2" to read "r57"
    Then the loader has run
      | atom | source | previous              |
      | f2   | r42    | Loading(r42)          |
      | f2   | r57    | Ready(r42, 800 × 400) |
    And the live atoms are
      | atom | live                   |
      | f2   | Ready(r57, 600 × 300)  |

  Scenario: A new image on its way keeps the previous image on screen
    Given a section
      | block | text                                |
      | a     | An open cover of the unit interval: |
      | b     | :: {{f2}}║                          |
    And its atoms
      | atom | rule  | source |
      | f2   | image | r42    |
    And the records
      | record | title      | description                        | width | height | bytes  |
      | r42    | cover.png  | Three open intervals cover [0, 1]. | 800   | 400    | device |
      | r57    | finite.png | Two of the intervals cover [0, 1]. | 600   | 300    | on way |
    When the person edits atom "f2" to read "r57"
    Then the live atoms are
      | atom | live                   |
      | f2   | Ready(r42, 800 × 400)  |
    And atom "f2" draws an image described as "Three open intervals cover [0, 1]."

  Scenario: An atom that leaves the section loses its live atom
    Given a section
      | block | text                                |
      | a     | An open cover of the unit interval:║ |
      | b     | :: {{f2}}                           |
    And its atoms
      | atom | rule  | source |
      | f2   | image | r42    |
    And the records
      | record | title     | description                        | width | height | bytes  |
      | r42    | cover.png | Three open intervals cover [0, 1]. | 800   | 400    | device |
    When a row lands
      | block | text                                |
      | a     | An open cover of the unit interval: |
    Then the live atoms are empty

  Scenario: An atom that lands from another device gets a live atom
    Given a section
      | block | text                                |
      | a     | An open cover of the unit interval:║ |
    And the records
      | record | title     | description                        | width | height | bytes  |
      | r42    | cover.png | Three open intervals cover [0, 1]. | 800   | 400    | device |
    When a row lands
      | block | text                                |
      | a     | An open cover of the unit interval: |
      | b     | :: {{f2}}                           |
    And its atoms
      | atom | rule  | source |
      | f2   | image | r42    |
    Then the live atoms are
      | atom | live                   |
      | f2   | Ready(r42, 800 × 400)  |

  # ── What stays the same object ─────────────────────────────────────────

  Scenario: Placing an atom writes into its param object
    Given a section
      | block | text                                |
      | a     | An open cover of the unit interval: |
      | b     | :: {{f2}}║                          |
    And its atoms
      | atom | rule  | source | param     |
      | f2   | image | r42    | width=50% |
    When the person places atom "f2" at "width=30%"
    Then atom "f2" is the same object
    And the param of atom "f2" is the same object
    And the param of atom "f2" is "width=30%"

  Scenario: Placing an atom removes a key the new param leaves out
    Given a section
      | block | text                                |
      | a     | An open cover of the unit interval: |
      | b     | :: {{f2}}║                          |
    And its atoms
      | atom | rule  | source | param                |
      | f2   | image | r42    | width=50%, rotate=90 |
    When the person places atom "f2" at "width=50%"
    Then the param of atom "f2" is the same object
    And the param of atom "f2" is "width=50%"

  Scenario: Editing a formula writes into the same atom
    Given a section
      | block | text                                   |
      | a     | A set {{a8f1}} is open by definition.║ |
    And its atoms
      | atom | rule | source     |
      | a8f1 | math | U \in \tau |
    When the person edits atom "a8f1" to read "U \subseteq X"
    Then atom "a8f1" is the same object
    And the live atom of "a8f1" is the same object
    And the live atoms are
      | atom | live          |
      | a8f1 | U \subseteq X |

  Scenario: Typing in a block keeps every atom
    Given a section
      | block | text                                   |
      | a     | A set {{a8f1}} is open by definition.║ |
      | b     | :: {{f2}}                              |
    And its atoms
      | atom | rule  | source     | param     |
      | a8f1 | math  | U \in \tau |           |
      | f2   | image | r42        | width=50% |
    When the person types "A set {{a8f1}} is open by its definition.║"
    Then the atoms are the same object
    And atom "a8f1" is the same object
    And atom "f2" is the same object
    And the param of atom "f2" is the same object
    And the live atoms are the same object
    And the live atom of "a8f1" is the same object

  Scenario: A landed row writes into the same atom
    Given a section
      | block | text                                |
      | a     | An open cover of the unit interval:║ |
      | b     | :: {{f2}}                           |
    And its atoms
      | atom | rule  | source | param     |
      | f2   | image | r42    | width=50% |
    And the records
      | record | title     | description                        | width | height | bytes  |
      | r42    | cover.png | Three open intervals cover [0, 1]. | 800   | 400    | device |
    When a row lands
      | block | text                                |
      | a     | An open cover of the unit interval: |
      | b     | :: {{f2}}                           |
    And its atoms
      | atom | rule  | source | param     |
      | f2   | image | r42    | width=30% |
    Then atom "f2" is the same object
    And the param of atom "f2" is the same object
    And the param of atom "f2" is "width=30%"
    And the loader was called once for each atom
      | atom |
      | f2   |

  Scenario: A new atom leaves the other atoms as they were
    Given a section
      | block | text                                |
      | a     | An open cover of the unit interval:║ |
      | b     | :: {{f2}}                           |
    And its atoms
      | atom | rule  | source |
      | f2   | image | r42    |
    And the records
      | record | title      | description                        | width | height | bytes  |
      | r42    | cover.png  | Three open intervals cover [0, 1]. | 800   | 400    | device |
      | r57    | finite.png | Two of the intervals cover [0, 1]. | 600   | 300    | device |
    When a row lands
      | block | text                                |
      | a     | An open cover of the unit interval: |
      | b     | :: {{f2}}                           |
      | c     | :: {{f3}}                           |
    And its atoms
      | atom | rule  | source |
      | f2   | image | r42    |
      | f3   | image | r57    |
    Then the atoms are the same object
    And atom "f2" is the same object
    And the live atoms are the same object
    And the loader was called once for each atom
      | atom |
      | f2   |
      | f3   |

  # ── Drawing ────────────────────────────────────────────────────────────

  Scenario: An image draws at the width its param gives
    Given a section
      | block | text                                |
      | a     | An open cover of the unit interval:║ |
      | b     | :: {{f2}}                           |
    And its atoms
      | atom | rule  | source | param     |
      | f2   | image | r42    | width=50% |
    And the records
      | record | title     | description                        | width | height | bytes  |
      | r42    | cover.png | Three open intervals cover [0, 1]. | 800   | 400    | device |
    Then atom "f2" draws an image "50%" wide, described as "Three open intervals cover [0, 1]."

  Scenario: An image on its way draws a placeholder
    Given a section
      | block | text                                |
      | a     | An open cover of the unit interval:║ |
      | b     | :: {{f2}}                           |
    And its atoms
      | atom | rule  | source |
      | f2   | image | r42    |
    And the records
      | record | title     | description                        | width | height | bytes  |
      | r42    | cover.png | Three open intervals cover [0, 1]. | 800   | 400    | on way |
    Then atom "f2" draws a placeholder

  # ── The rule's editor ──────────────────────────────────────────────────

  Scenario: A param from the editor is typed text
    Given a section
      | block | text                                |
      | a     | An open cover of the unit interval: |
      | b     | :: {{f2}}║                          |
    And its atoms
      | atom | rule  | source |
      | f2   | image | r42    |
    And the records
      | record | title     | description                        | width | height | bytes  |
      | r42    | cover.png | Three open intervals cover [0, 1]. | 800   | 400    | device |
    When the editor of atom "f2" changes its param to "width=50%"
    Then the typed text is
      | atom | rule  | source | param     |
      | f2   | image | r42    | width=50% |
    And the port receives nothing

  Scenario: A text from the editor is typed text
    Given a section
      | block | text                                |
      | a     | An open cover of the unit interval: |
      | b     | :: {{f2}}║                          |
    And its atoms
      | atom | rule  | source |
      | f2   | image | r42    |
    When the editor of atom "f2" changes its text to "r57"
    Then the typed text is
      | atom | rule  | source |
      | f2   | image | r57    |
    And the port receives nothing

  Scenario: Closing the editor leaves the caret after the atom
    Given a section
      | block | text                                |
      | a     | An open cover of the unit interval:║ |
      | b     | :: {{f2}}                           |
    And its atoms
      | atom | rule  | source |
      | f2   | image | r42    |
    When the person clicks atom "f2"
    And the editor of atom "f2" closes
    Then no editor is open
    And the caret is after atom "f2"
