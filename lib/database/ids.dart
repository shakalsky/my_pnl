import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Generates a new primary key.
///
/// UUID v7 is time-ordered: the leading 48 bits are a millisecond timestamp,
/// so freshly generated ids sort by creation time and land at the right edge
/// of the index instead of scattering across it the way v4 does.
///
/// Ids are always generated on the client, never by the server. That keeps
/// inserts possible offline, makes uploads idempotent (a retry is an upsert on
/// a known key rather than a second row), and means a foreign key written
/// offline stays correct forever.
String newId() => _uuid.v7();

/// A stable id derived from [name], for rows that must not be created twice.
///
/// UUIDv5 hashes the name, so the same input always yields the same id. That
/// makes a generated row idempotent across devices as well as across runs:
/// two phones catching up on the same missed month produce the same id, and
/// the second upload is an upsert rather than a duplicate. Random ids cannot
/// give that, because neither device can see the other's write yet.
String derivedId(String name) => _uuid.v5(Namespace.url.value, name);
