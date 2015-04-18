exports.module =
  # Greek
  'kosme': 'κόσμε'
  # 1 byte (U-00000000)
  '2.1.1': ' '
  # 2 bytes (U-00000080)
  '2.1.2': ''
  # 3 bytes (U-00000800)
  '2.1.3': 'ࠀ'
  # 4 bytes (U-00010000)
  '2.1.4': '𐀀'
  # 5 bytes (U-00200000)
  '2.1.5': '�����'
  # 6 bytes (U-04000000)
  '2.1.6': '������'
  # 1 byte (U-0000007F)
  '2.2.1': ''
  # 2 bytes (U-000007FF)
  '2.2.2': '߿'
  # 3 bytes (U-0000FFFF)
  '2.2.3': '￿'
  # 4 bytes (U-001FFFFF)
  '2.2.4': '����'
  # 5 bytes (U-03FFFFFF)
  '2.2.5': '�����'
  # 6 bytes (U-7FFFFFFF)
  '2.2.6': '������'
  # U-0000D7FF = ed 9f bf
  '2.3.1': '퟿'
  # U-0000E000 = ee 80 80
  '2.3.2': ''
  # U-0000FFFD = ef bf bd
  '2.3.3': '�'
  # U-0010FFFF = f4 8f bf bf
  '2.3.4': '􏿿'
  # U-00110000 = f4 90 80 80
  '2.3.5': '����'
  # First continuation byte 0x80
  '3.1.1': '�'
  # Last continuation byte 0xbf
  '3.1.2': '�'
  # 2 continuation bytes
  '3.1.3': '��'
  # 3 continuation bytes
  '3.1.4': '���'
  # 4 continuation bytes
  '3.1.5': '����'
  # 5 continuation bytes
  '3.1.6': '�����'
  # 6 continuation bytes
  '3.1.7': '������'
  # 7 continuation bytes
  '3.1.8': '�������'
  # Sequence of all 64 possible continuation bytes (0x80-0xbf)
  '3.1.9': '����������������������������������������������������������������'
  # All 32 first bytes of 2-byte sequences (0xc0-0xdf) each followed by a space character
  '3.2.1': '� � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � '
  # All 16 first bytes of 3-byte sequences (0xe0-0xef) each followed by a space character
  '3.2.2': '� � � � � � � � � � � � � � � � '
  # All 8 first bytes of 4-byte sequences (0xf0-0xf7) each followed by a space character
  '3.2.3': '� � � � � � � � '
  # All 4 first bytes of 5-byte sequences (0xf8-0xfb) each followed by a space character
  '3.2.4': '� � � � '
  # All 2 first bytes of 6-byte sequences (0xfc-0xfd) each followed by a space character
  '3.2.5': '� � '
  # 2-byte sequence with last byte missing (U+0000)
  '3.3.1': '�'
  # 3-byte sequence with last byte missing (U+0000)
  '3.3.2': '��'
  # 4-byte sequence with last byte missing (U+0000)
  '3.3.3': '���'
  # 5-byte sequence with last byte missing (U+0000)'
  '3.3.4': '����'
  # 6-byte sequence with last byte missing (U+0000)
  '3.3.5': '�����'
  # 2-byte sequence with last byte missing (U-000007FF)
  '3.3.6': '�'
  # 3-byte sequence with last byte missing (U-0000FFFF)
  '3.3.7': '�'
  # 4-byte sequence with last byte missing (U-001FFFFF)
  '3.3.8': '���'
  # 5-byte sequence with last byte missing (U-03FFFFFF)
  '3.3.9': '����'
  # 6-byte sequence with last byte missing (U-7FFFFFFF)
  '3.3.10': '�����'
  # All 10 sequences of 3.3 concatenated
  '3.4': '�����������������������������'
  # fe
  '3.5.1': '�'
  # ff
  '3.5.2': '�'
  # fe fe ff ff
  '3.5.3': '����'
  # U+002F = c0 af
  '4.1.1': '��'
  # U+002F = e0 80 af
  '4.1.2': '���'
  # U+002F = f0 80 80 af
  '4.1.3': '����'
  # U+002F = f8 80 80 80 af
  '4.1.4': '�����'
  # U+002F = fc 80 80 80 80 af
  '4.1.5': '������'
  # U-0000007F = c1 bf
  '4.2.1': '��'
  # U-000007FF = e0 9f bf
  '4.2.2': '���'
  # U-0000FFFF = f0 8f bf bf
  '4.2.3': '����'
  # U-001FFFFF = f8 87 bf bf bf
  '4.2.4': '�����'
  # U-03FFFFFF = fc 83 bf bf bf bf
  '4.2.5': '������'
  # U+0000 = c0 80
  '4.3.1': '��'
  # U+0000 = e0 80 80
  '4.3.2': '���'
  # U+0000 = f0 80 80 80
  '4.3.3': '����'
  # U+0000 = f8 80 80 80 80
  '4.3.4': '�����'
  # U+0000 = fc 80 80 80 80 80
  '4.3.5': '������'
  # U+D800 = ed a0 80
  '5.1.1': '���'
  # U+DB7F = ed ad bf
  '5.1.2': '���'
  # U+DB80 = ed ae 80
  '5.1.3': '���'
  # U+DBFF = ed af bf
  '5.1.4': '���'
  # U+DC00 = ed b0 80
  '5.1.5': '���'
  # U+DF80 = ed be 80
  '5.1.6': '���'
  # U+DFFF = ed bf bf
  '5.1.7': '���'
  # U+D800 U+DC00 = ed a0 80 ed b0 80
  '5.2.1': '������'
  # U+D800 U+DFFF = ed a0 80 ed bf bf
  '5.2.2': '������'
  # U+DB7F U+DC00 = ed ad bf ed b0 80
  '5.2.3': '������'
  # U+DB7F U+DFFF = ed ad bf ed bf bf
  '5.2.4': '������'
  # U+DB80 U+DC00 = ed ae 80 ed b0 80
  '5.2.5': '������'
  # U+DB80 U+DFFF = ed ae 80 ed bf bf
  '5.2.6': '������'
  # U+DBFF U+DC00 = ed af bf ed b0 80
  '5.2.7': '������'
  # U+DBFF U+DFFF = ed af bf ed bf bf
  '5.2.8': '������'
  # U+FFFE = ef bf be
  '5.3.1': '￾'
  # U+FFFFee = ef bf bf
  '5.3.2': '￿'
