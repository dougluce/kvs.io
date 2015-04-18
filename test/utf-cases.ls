#
# Extracted from  http://www.cl.cam.ac.uk/~mgk25/ucs/examples/UTF-8-test.txt
#

#
# The ones that are commented out oughta be fixed!
#

module.exports =
  'Greek': 'κόσμε'
  '2 bytes (U-00000080)': ''
  '3 bytes (U-00000800)': 'ࠀ'
  '4 bytes (U-00010000)': '𐀀'
  '5 bytes (U-00200000)': '�����'
  '6 bytes (U-04000000)': '������'
  '2 bytes (U-000007FF)': '߿'
  '3 bytes (U-0000FFFF)': '￿'
  '4 bytes (U-001FFFFF)': '����'
  '5 bytes (U-03FFFFFF)': '�����'
  '6 bytes (U-7FFFFFFF)': '������'
  'U-0000D7FF = ed 9f bf': '퟿'
  'U-0000E000 = ee 80 80': ''
  'U-0000FFFD = ef bf bd': '�'
  'U-0010FFFF = f4 8f bf bf': '􏿿'
  'U-00110000 = f4 90 80 80': '����'
  'First continuation byte 0x80': '�'
  'Last continuation byte 0xbf': '�'
  '2 continuation bytes': '��'
  '3 continuation bytes': '���'
  '4 continuation bytes': '����'
  '5 continuation bytes': '�����'
  '6 continuation bytes': '������'
  '7 continuation bytes': '�������'
  'Sequence of all 64 possible continuation bytes (0x80-0xbf)': '����������������������������������������������������������������'
  '2-byte sequence with last byte missing (U+0000)': '�'
  '3-byte sequence with last byte missing (U+0000)': '��'
  '4-byte sequence with last byte missing (U+0000)': '���'
  '5-byte sequence with last byte missing (U+0000)': '����'
  '6-byte sequence with last byte missing (U+0000)': '�����'
  '2-byte sequence with last byte missing (U-000007FF)': '�'
  '3-byte sequence with last byte missing (U-0000FFFF)': '�'
  '4-byte sequence with last byte missing (U-001FFFFF)': '���'
  '5-byte sequence with last byte missing (U-03FFFFFF)': '����'
  '6-byte sequence with last byte missing (U-7FFFFFFF)': '�����'
  'All 10 sequences above concatenated': '�����������������������������'
  'fe': '�'
  'ff': '�'
  'fe fe ff ff': '����'
  'U+002F = c0 af': '��'
  'U+002F = e0 80 af': '���'
  'U+002F = f0 80 80 af': '����'
  'U+002F = f8 80 80 80 af': '�����'
  'U+002F = fc 80 80 80 80 af': '������'
  'U-0000007F = c1 bf': '��'
  'U-000007FF = e0 9f bf': '���'
  'U-0000FFFF = f0 8f bf bf': '����'
  'U-001FFFFF = f8 87 bf bf bf': '�����'
  'U-03FFFFFF = fc 83 bf bf bf bf': '������'
  'U+0000 = c0 80': '��'
  'U+0000 = e0 80 80': '���'
  'U+0000 = f0 80 80 80': '����'
  'U+0000 = f8 80 80 80 80': '�����'
  'U+0000 = fc 80 80 80 80 80': '������'
  'U+D800 U+DC00 = ed a0 80 ed b0 80': '������'
  'U+D800 U+DFFF = ed a0 80 ed bf bf': '������'
  'U+DB7F U+DC00 = ed ad bf ed b0 80': '������'
  'U+DB7F U+DFFF = ed ad bf ed bf bf': '������'
  'U+DB80 U+DC00 = ed ae 80 ed b0 80': '������'
  'U+DB80 U+DFFF = ed ae 80 ed bf bf': '������'
  'U+DBFF U+DC00 = ed af bf ed b0 80': '������'
  'U+DBFF U+DFFF = ed af bf ed bf bf': '������'
  'U+FFFE = ef bf be': '￾'
  'U+FFFFee = ef bf bf': '￿'
  # Pangrams with spaces changed to _
  'Danish': 'Quizdeltagerne_spiste_jordbær_med_fløde,_mens_cirkusklovnen_Wolther_spillede_på_xylofon.'
  'German 1': 'Falsches_Üben_von_Xylophonmusik_quält_jeden_größeren_Zwerg'
  'German 2': 'Zwölf_Boxkämpfer_jagten_Eva_quer_über_den_Sylter_Deich'
  'German 3': 'Heizölrückstoßabdämpfung'
  'Greek 1': 'Γαζέες_καὶ_μυρτιὲς_δὲν_θὰ_βρῶ_πιὰ_στὸ_χρυσαφὶ_ξέφωτο'
  'Greek 2': 'Ξεσκεπάζω_τὴν_ψυχοφθόρα_βδελυγμία'
  'English': 'The_quick_brown_fox_jumps_over_the_lazy_dog'
  'Spanish': 'El_pingüino_Wenceslao_hizo_kilómetros_bajo_exhaustiva_lluvia_y_frío,_añoraba_a_su_querido_cachorro.'
  'French 1': "Portez_ce_vieux_whisky_au_juge_blond_qui_fume_sur_son_île_intérieure,_à_côté_de_l'alcôve_ovoïde,_où_les_bûches_se_consument_dans_l'âtre,_ce_qui_lui_permet_de_penser_à_la_cænogenèse_de_l'être_dont_il_est_question_dans_la_cause_ambiguë_entendue_à_Moÿ,_dans_un_capharnaüm_qui,_pense-t-il,_diminue_çà_et_là_la_qualité_de_son_œuvre."
  'French 2': "l'île_exiguë_Où_l'obèse_jury_mûr_Fête_l'haï_volapük,_Âne_ex_aéquo_au_whist,_Ôtez_ce_vœu_déçu."
  'French 3': "Le_cœur_déçu_mais_l'âme_plutôt_naïve,_Louÿs_rêva_de_crapaüter_en_canoë_au_delà_des_îles,_près_du_mälström_où_brûlent_les_novæ."
  'Irish_Gaelic': 'Dfhuascail_Íosa,_Úrmhac_na_hÓighe_Beannaithe,_pór_Éava_agus_Ádhaimh'
  'Hungarian': 'Árvíztűrő_tükörfúrógép'
  'Icelandic 1': 'Kæmi_ný_öxi_hér_ykist_þjófum_nú_bæði_víl_og_ádrepa'
  'Icelandic 2': 'Sævör_grét_áðan_því_úlpan_var_ónýt'
  'Hiragana 1': 'いろはにほへとちりぬるを'
  'Hiragana 2': 'わかよたれそつねならむ'
  'Hiragana 3': 'うゐのおくやまけふこえて'
  'Hiragana 4': 'あさきゆめみしゑひもせす'
  'Katakana 1': 'イロハニホヘト_チリヌルヲ_ワカヨタレソ_ツネナラム'
  'Katakana 2': 'ウヰノオクヤマ_ケフコエテ_アサキユメミシ_ヱヒモセスン'
  'Hebrew': '_דג_סקרן_שט_בים_מאוכזב_ולפתע_מצא_לו_חברה_איך_הקליטה'
  'Polish': 'Pchnąć_w_tę_łódź_jeża_lub_ośm_skrzyń_fig'
  'Russian 1': 'В_чащах_юга_жил_бы_цитрус_Да,_но_фальшивый_экземпляр'
  'Russian 2': 'Съешь_же_ещё_этих_мягких_французских_булок_да_выпей_чаю'
  'Thai 1': '๏_เป็นมนุษย์สุดประเสริฐเลิศคุณค่า__กว่าบรรดาฝูงสัตว์เดรัจฉาน'
  'Thai 2': 'จงฝ่าฟันพัฒนาวิชาการ___________อย่าล้างผลาญฤๅเข่นฆ่าบีฑาใคร'
  'Thai 3': 'ไม่ถือโทษโกรธแช่งซัดฮึดฮัดด่า_____หัดอภัยเหมือนกีฬาอัชฌาสัย'
  'Thai 4': 'ปฏิบัติประพฤติกฎกำหนดใจ________พูดจาให้จ๊ะๆ_จ๋าๆ_น่าฟังเอย_ฯ'
  'Turkish':'Pijamalı_hasta,_yağız_şoföre_çabucak_güvendi.'

#
# Can't really have spaces in the URI, so bail on these
#

with_spaces =
  'All 32 first bytes of 2-byte sequences (0xc0-0xdf) each followed by a space character': '� � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � '
  'All 16 first bytes of 3-byte sequences (0xe0-0xef) each followed by a space character': '� � � � � � � � � � � � � � � � '
  'All 8 first bytes of 4-byte sequences (0xf0-0xf7) each followed by a space character': '� � � � � � � � '
  'All 4 first bytes of 5-byte sequences (0xf8-0xfb) each followed by a space character': '� � � � '
  'All 2 first bytes of 6-byte sequences (0xfc-0xfd) each followed by a space character': '� � '


# These cause the server socket to close.
crashers =
  '1 byte (U-00000000)': ' '
  '1 byte (U-0000007F)': ''

# These all result in URIError: URI malformed
malformed =
  'U+D800 = ed a0 80': '���'
  'U+DB7F = ed ad bf': '���'
  'U+DB80 = ed ae 80': '���'
  'U+DBFF = ed af bf': '���'
  'U+DC00 = ed b0 80': '���'
  'U+DF80 = ed be 80': '���'
  'U+DFFF = ed bf bf': '���'
