#
# Extracted from  http://www.cl.cam.ac.uk/~mgk25/ucs/examples/UTF-8-test.txt
#

module.exports =
  # Greek
  'κόσμε'
  # 1 byte (U-00000000)
  #' '
  # 2 bytes (U-00000080)
  ''
  # 3 bytes (U-00000800)
  'ࠀ'
  # 4 bytes (U-00010000)
  '𐀀'
  # 5 bytes (U-00200000)
  '�����'
  # 6 bytes (U-04000000)
  '������'
  # 1 byte (U-0000007F)
  ''
  # 2 bytes (U-000007FF)
  '߿'
  # 3 bytes (U-0000FFFF)
  '￿'
  # 4 bytes (U-001FFFFF)
  '����'
  # 5 bytes (U-03FFFFFF)
  '�����'
  # 6 bytes (U-7FFFFFFF)
  '������'
  # U-0000D7FF = ed 9f bf
  '퟿'
  # U-0000E000 = ee 80 80
  ''
  # U-0000FFFD = ef bf bd
  '�'
  # U-0010FFFF = f4 8f bf bf
  '􏿿'
  # U-00110000 = f4 90 80 80
  '����'
  # First continuation byte 0x80
  '�'
  # Last continuation byte 0xbf
  '�'
  # 2 continuation bytes
  '��'
  # 3 continuation bytes
  '���'
  # 4 continuation bytes
  '����'
  # 5 continuation bytes
  '�����'
  # 6 continuation bytes
  '������'
  # 7 continuation bytes
  '�������'
  # Sequence of all 64 possible continuation bytes (0x80-0xbf)
  '����������������������������������������������������������������'
  # All 32 first bytes of 2-byte sequences (0xc0-0xdf) each followed by a space character
  '� � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � '
  # All 16 first bytes of 3-byte sequences (0xe0-0xef) each followed by a space character
  '� � � � � � � � � � � � � � � � '
  # All 8 first bytes of 4-byte sequences (0xf0-0xf7) each followed by a space character
  '� � � � � � � � '
  # All 4 first bytes of 5-byte sequences (0xf8-0xfb) each followed by a space character
  '� � � � '
  # All 2 first bytes of 6-byte sequences (0xfc-0xfd) each followed by a space character
  '� � '
  # 2-byte sequence with last byte missing (U+0000)
  '�'
  # 3-byte sequence with last byte missing (U+0000)
  '��'
  # 4-byte sequence with last byte missing (U+0000)
  '���'
  # 5-byte sequence with last byte missing (U+0000)'
  '����'
  # 6-byte sequence with last byte missing (U+0000)
  '�����'
  # 2-byte sequence with last byte missing (U-000007FF)
  '�'
  # 3-byte sequence with last byte missing (U-0000FFFF)
  '�'
  # 4-byte sequence with last byte missing (U-001FFFFF)
  '���'
  # 5-byte sequence with last byte missing (U-03FFFFFF)
  '����'
  # 6-byte sequence with last byte missing (U-7FFFFFFF)
   '�����'
  # All 10 sequences above concatenated
  '�����������������������������'
  # fe
  '�'
  # ff
  '�'
  # fe fe ff ff
  '����'
  # U+002F = c0 af
  '��'
  # U+002F = e0 80 af
  '���'
  # U+002F = f0 80 80 af
  '����'
  # U+002F = f8 80 80 80 af
  '�����'
  # U+002F = fc 80 80 80 80 af
  '������'
  # U-0000007F = c1 bf
  '��'
  # U-000007FF = e0 9f bf
  '���'
  # U-0000FFFF = f0 8f bf bf
  '����'
  # U-001FFFFF = f8 87 bf bf bf
  '�����'
  # U-03FFFFFF = fc 83 bf bf bf bf
  '������'
  # U+0000 = c0 80
  '��'
  # U+0000 = e0 80 80
  '���'
  # U+0000 = f0 80 80 80
  '����'
  # U+0000 = f8 80 80 80 80
  '�����'
  # U+0000 = fc 80 80 80 80 80
  '������'
  # U+D800 = ed a0 80
  '���'
  # U+DB7F = ed ad bf
  '���'
  # U+DB80 = ed ae 80
  '���'
  # U+DBFF = ed af bf
  '���'
  # U+DC00 = ed b0 80
  '���'
  # U+DF80 = ed be 80
  '���'
  # U+DFFF = ed bf bf
  '���'
  # U+D800 U+DC00 = ed a0 80 ed b0 80
  '������'
  # U+D800 U+DFFF = ed a0 80 ed bf bf
  '������'
  # U+DB7F U+DC00 = ed ad bf ed b0 80
  '������'
  # U+DB7F U+DFFF = ed ad bf ed bf bf
  '������'
  # U+DB80 U+DC00 = ed ae 80 ed b0 80
  '������'
  # U+DB80 U+DFFF = ed ae 80 ed bf bf
  '������'
  # U+DBFF U+DC00 = ed af bf ed b0 80
  '������'
  # U+DBFF U+DFFF = ed af bf ed bf bf
  '������'
  # U+FFFE = ef bf be
  '￾'
  # U+FFFFee = ef bf bf
  '￿'
