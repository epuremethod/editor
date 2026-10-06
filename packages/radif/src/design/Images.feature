Feature: Images

  For a reader of the course who pastes a figure into a section, and for
  the people who edit the course with them.

  A pasted image is a row of `Image`. The section holds an atom whose rule
  is `image` and whose text is the row's id. `paste` makes the row from the
  file and answers the atom at once: it never waits for a save or an
  upload. The row is a draft, since it has no description yet. It sits
  under the document, and it carries no `Attached`: the atom names it, and
  no list shows it.

  `image` is the loader of the image rule. It reads the row, drafts
  included, and the bytes the row names. While the image loads, it draws
  the blob when the device holds it, and a placeholder when it does not.
  Once the bytes are stored and on the device, it draws the stored image.
  So a pasted image shows at once, before its row is read back. It keeps
  its file on screen after the upload, since the bytes are the same, and
  releases the file when it leaves the section.

  While this device uploads the bytes, the image shows the upload over the
  file: how far it has gone, and what it waits for. The overlay goes once
  the bucket holds the bytes and the push that names them lands. A file
  pasted before a reload still uploads after it, so the image shows its
  upload again. An image that only came down from the bucket shows no
  overlay. While its bytes come down, its placeholder shows how far the
  download has gone.

  The world is Ben's course, "Open sets", over a real client and a wire
  that each scenario answers. A row "from another device" is one that a
  pull brings.

  Background:
    Given Ben's course "Open sets"

  # ── Pasting ────────────────────────────────────────────────────────────

  Scenario: Pasting an image answers an image atom at once
    When Ben pastes the image "cover.png" of 800 × 400 pixels
    Then the paste answers an atom of rule "image"
    And its text is the id of a new row of Image

  Scenario: The pasted image is a draft under the course
    When Ben pastes the image "cover.png" of 800 × 400 pixels
    Then the course holds an image draft
      | title     | width | height |
      | cover.png | 800   | 400    |

  Scenario: The pasted image is attached to nothing
    When Ben pastes the image "cover.png" of 800 × 400 pixels
    Then the pasted image has no parents

  Scenario: The pasted image keeps its bytes on the device
    When Ben pastes the image "cover.png" of 800 × 400 pixels
    Then the pasted image names bytes the device holds

  Scenario: Pasting while offline still answers the atom
    Given Ben is offline
    When Ben pastes the image "cover.png" of 800 × 400 pixels
    Then the paste answers an atom of rule "image"
    And nothing was pushed

  Scenario: A file that is not an image is not taken
    When Ben pastes the file "notes.txt"
    Then the paste answers nothing
    And the course holds no image

  # ── Drawing ────────────────────────────────────────────────────────────

  Scenario: A pasted image shows its file at once
    When Ben pastes the image "cover.png" of 800 × 400 pixels
    Then before any read answers, the image draws the pasted file

  Scenario: A pasted image shows its file while it uploads
    Given Ben is offline
    When Ben pastes the image "cover.png" of 800 × 400 pixels
    And every read has answered
    Then the image draws the pasted file

  Scenario: A pasted image keeps its file on screen once its bytes are stored
    When Ben pastes the image "cover.png" of 800 × 400 pixels
    And the push lands
    Then the image draws the pasted file
    And the image is ready

  # ── Uploading ──────────────────────────────────────────────────────────

  Scenario: An image pasted offline shows its upload waiting for the network
    Given Ben is offline
    When Ben pastes the image "cover.png" of 800 × 400 pixels
    Then the image shows its upload waiting for the network

  Scenario: A pasted image shows how far its upload has gone
    When Ben pastes the image "cover.png" of 800 × 400 pixels
    And half of its bytes are sent
    Then the image draws the pasted file
    And the image shows its upload at 50%

  Scenario: A pasted image shows its upload saving once every byte is sent
    When Ben pastes the image "cover.png" of 800 × 400 pixels
    And every byte is sent and the push is in flight
    Then the image shows its upload saving

  Scenario: A pasted image shows its upload trying again after a refused part
    When Ben pastes the image "cover.png" of 800 × 400 pixels
    And the bucket refuses the first part
    Then the image shows its upload trying again

  Scenario: A pasted image shows no upload once its push lands
    When Ben pastes the image "cover.png" of 800 × 400 pixels
    And the push lands
    Then the image shows no upload

  Scenario: An image pasted before a reload shows its upload after it
    Given Ben is offline
    When Ben pastes the image "cover.png" of 800 × 400 pixels
    And Ben opens the course again
    Then the image draws the kept file
    And the image shows its upload waiting for the network

  Scenario: A pasted image that leaves the section releases its file
    When Ben pastes the image "cover.png" of 800 × 400 pixels
    And the image leaves the section
    Then the pasted file is released

  Scenario: An image whose row has not arrived draws a placeholder
    When an atom names the row "r42" that no pull has brought
    Then the image "r42" draws a placeholder

  Scenario: An image the reader cannot reach says so
    When an atom names the row "r42"
    And the pull answers that "r42" does not exist
    Then the image "r42" says it is not available

  Scenario: An image from another device draws a placeholder of its size
    When an atom names the row "r42"
    And a pull brings the image "r42" titled "finite.png" of 600 × 300 pixels
    Then the image "r42" draws a placeholder of 600 × 300

  Scenario: An image from another device shows how far its download has gone
    When an atom names the row "r42"
    And a pull brings the image "r42" titled "finite.png" of 600 × 300 pixels
    And half of its bytes arrive
    Then the image "r42" draws a placeholder of 600 × 300
    And the image "r42" shows its download at 50%

  Scenario: An image from another device shows once its bytes arrive
    When an atom names the row "r42"
    And a pull brings the image "r42" titled "finite.png" of 600 × 300 pixels
    And its bytes arrive
    Then the image "r42" draws the stored bytes
    And the image "r42" shows no upload

  Scenario: An image draft from another device shows like a stored image
    When an atom names the row "r42"
    And a pull brings the image draft "r42" titled "finite.png" of 600 × 300 pixels
    And its bytes arrive
    Then the image "r42" draws the stored bytes
