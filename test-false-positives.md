# Legitimate prose that must stay clean

This fixture sits close to each rule's pattern without crossing it, so
the test-clean recipe can assert zero findings.

## Colons in running text

The recipe needs one input: the path to the fixture document. Trailers
such as Signed-off-by: Tony Burns survive through the commit-trailer
exemption in the colon rule.

## Acronyms with definitions

The Rule Definition Language (RDL) drives the engine, and RDL files
parse as YAML. An API reference sits in the exceptions list, so neither
acronym needs a spelled-out first use here.
