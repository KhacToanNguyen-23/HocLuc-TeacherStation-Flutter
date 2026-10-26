/// Comprehensive offline lexical database mapping English words to CEFR levels (A1–C2),
/// frequency bands (K1–K3+), and Academic Word List (AWL) classification.
/// Derived from Oxford 3000/5000, CEFR-J, and Coxhead Academic Word List.
class CefrDictionaryData {
  /// Academic Word List (AWL) subset
  static const List<String> _academicWordChunks = [
    'abstract academy accurate achieve acknowledged acquisition adjust administration affect aggregate allocation alter',
    'alternative amendment analysis apparent approach appropriate area aspects assessment assigned assistance assume',
    'attached attitude attribute author authority available aware benefit bond brief capable capacity',
    'categories challenge chapter circumstances cite civil clause code comments commission commitment communication',
    'community compensation complex components compounds computer concentration concept conclusion conduct conference conflict',
    'consent consequences considerable consistent constant constitutional constraints construction consultation consumer contact context',
    'contract contrast contribution convention cooperative coordination core corporate corresponding create credit criteria',
    'cultural cycle data debate decline deduction definition demonstrate derived design despite dimension',
    'discretion discrimination display distinction distribution diversity document domain domestic dominant draft economic',
    'edition elements emerged emphasis enable energy enforcement enhanced ensure entities environment equation',
    'equivalent error established estate estimate ethnic evaluation evidence evolution exceed excluded expansion',
    'explicit export exposure external facilitate factors feasible features federal fees final financial',
    'flexibility focus formula framework function fundamental funds furthermore gender generate generation goals',
    'granted hypothesis identified illustrated image immigrate impact implementation implications implies imposed incentive',
    'income incorporate index indicate individual inevitable inhibition initial initiatives injury input instance',
    'institute instructions integration intelligence interaction internal interpretation interval investigation investment involved issues',
    'items journal justification labor layer legal legislation liberal licence link location logic',
    'maintenance major marginal maximum mechanism medical mental method migration minimum minority modified',
    'monitoring negative network neutral nevertheless normal notion objective obtained obvious occupational occur',
    'option orientation outcomes output overall overseas parallel parameters participation partnership perceived percent',
    'period perspective phase philosophy physical policy positive potential preceding precise predict presumption',
    'previous primary prime principal principle prior procedure process professional project promote proportion',
    'psychology published purchase pursue range ratio rational reaction recovery regime region registered',
    'regulations rejected relevant reliance removed required research resident resolution resources response restricted',
    'retained revealed revenue role scheme scope section sector security select sequence series',
    'shift significant similar site sought source specific specified stability statistics status strategies',
    'stress structure styles subsequent subsidiary substitution sufficient sum summary survey sustainable symbolic',
    'tape target task technical techniques technology text theory trace traditional transfer transformation',
    'transit transport trend underlying undertake unprecedented utility validity variables version volume welfare',
    'whereas',
  ];

  static final Set<String> academicWordList = _buildAwlSet();

  static Set<String> _buildAwlSet() {
    final set = <String>{};
    for (final chunk in _academicWordChunks) {
      for (final w in chunk.split(' ')) {
        if (w.isNotEmpty) set.add(w);
      }
    }
    return set;
  }

  static const List<String> _a1Chunks = [
    'a am an and apple are ask asked at ate bad be',
    'been big black blue book bus but came can car cat class',
    'cold come day desk did do does dog drank drink eat eight',
    'family five food for four friend from get go gone good got',
    'green had happy has have he her here him his home hot',
    'house i in is it listen made make me morning my name',
    'new night nine no not now old on one or our pen',
    'pencil read red room sad said saw say school see seven she',
    'six sleep slept small so speak spoke student take teacher tell ten',
    'that the their them there these they this those three to today',
    'told took two us was water we went were white will with',
    'write wrote yes you your',
  ];

  static const List<String> _a2Chunks = [
    'accident activity actor address adult advice afraid afternoon agree airport almost alone',
    'already always amazing angry animal answer apartment arrive article artist autumn beautiful',
    'become before begin believe birthday biscuit boring bottle bread bridge bright brother',
    'build building business busy camera capital careful centre century change cheap cheese',
    'chicken choose cinema city clean clever climb clothes cloud club coat coffee',
    'college colour comfortable company concert cook could country cousin crowded culture dangerous',
    'dark daughter decide delicious describe desert dictionary difference different difficult dinner direction',
    'doctor dollar driver early easily easy education email empty engine engineer enjoy',
    'enough enter evening every everybody everyone everything everywhere exam example excited exciting',
    'exercise expensive explain factory famous farm farmer fast favourite feel festival film',
    'finally find finish flight floor flower fly follow foreign forest forget free',
    'fresh fridge friendly future garden geography gift glass glove grammar grandfather grandmother',
    'grandparent group grow guitar habit half hand happen hate health healthy hear',
    'heart heavy help history hobby holiday hospital hotel hour hungry hurt husband',
    'ice important improve include information insect inside instead instrument interested interesting international',
    'internet interview into island jacket journey juice jump kind kitchen knife language',
    'large late laugh lazy learn leave lesson letter library lie life light',
    'line lion little local long look lose loud luck lucky lunch machine',
    'magazine main manager many map market marry may meal meaning meat medicine',
    'meet meeting member message metre midnight mile milk minute mirror miss mistake',
    'modern moment money monkey month moon more mountain mouse mouth museum music',
    'musician must national natural nature near nearly neck need neighbour news newspaper',
    'next nice nobody noise noisy noon north nose notice novel nurse object',
    'ocean offer office officer often online open opinion opposite outside parent park',
    'part party passport past pay photo photograph photographer piano picture piece place',
    'plane plant plate play player pleasant pocket police polite poor popular possible',
    'post practise prefer prepare present price prize problem programme project pupil quarter',
    'quick quiet railway rain ready real reason receive remember rent repair repeat',
    'restaurant return rich ride right river road safe sail salad sale same',
    'save science scientist season seat second secret sell send sentence serve share',
    'ship shirt shoe shop short should shower sick sight silver similar simple',
    'sing singer single sister sit size skirt slow smile smoke snow soap',
    'sock soft son song soon sorry sound soup south space special spell',
    'spend spoon sport spring square stadium stage stairs stamp stand star start',
    'station stay steak steal still stomach stop store storm story straight strange',
    'street strong study subject sugar suit summer sun sunny supermarket supper sure',
    'surprise surprised sweet swim swimming table talk tall taste taxi tea teach',
    'team teenager telephone television tennis terrible test text than thank theatre then',
    'thin thing think thirsty thousand through ticket tidy time tired together toilet',
    'tomorrow tonight tooth top tour tourist towel tower town traffic train travel',
    'tree trip trouble true try turn twice umbrella uncle under understand uniform',
    'university until unusual use useful usual usually vegetable very video village visit',
    'visitor wait waiter wake walk wall want warm wash watch way wear',
    'weather website week weekend welcome well west wheel when where which while',
    'who why wife win wind window windy winter wish without woman wonderful',
    'wood wooden word work worker world worry worst would yard year yesterday',
    'young',
  ];

  static const List<String> _b1Chunks = [
    'ability abroad absolute academic accept access accommodation account achievement act admit advantage',
    'advertisement afford against agency ahead aim alcoholic allow although amount amusing ancient',
    'announcement annoy anxious apart apologize appear appearance apply appointment appreciate appropriate approve',
    'architect architecture argue argument arrange arrangement arrest arrival ashamed asleep aspect assist',
    'athlete atmosphere attach attack attempt attend attitude attract attraction attractive audience author',
    'authority available average avoid award aware awful background badly balance base basic',
    'basis battle beauty behave behaviour belong benefit bitter blame blank blind block',
    'board boil bomb bone border bother bottom branch brave breath breathe broad',
    'burn bury calm campaign cancer candidate care career case cause celebrate certain',
    'certainly chain challenge chance character charge charity chat check cheerful chemical chest',
    'choice circle circumstance citizen claim climate clue coach coal coast collection combine',
    'comment commercial communicate communication community compete competition complain complaint complete completely complex',
    'concentrate concentration concept concern conclude conclusion condition conference confidence confident confirm confused',
    'confusing connect connection consequence consider consist contact contain content continue contract control',
    'convenient conversation convince cost cough count courage course court cover crash crazy',
    'create creature credit crew crime criminal crisis criterion critic critical criticism criticize',
    'crop cross crowd cruel cry cure curious curl current currently curtain custom',
    'customer damage danger deal death debate debt decade decision declare decline decorate',
    'decrease deep defeat defence defend define definite definitely definition degree delay deliberate',
    'deliver demand demonstrate dentist deny department depend deposit depressed depth description deserve',
    'design desire desperate despite destroy destruction detail detailed detect determine determined develop',
    'development device diagram dialogue diet differ digital direct directly director dirt disabled',
    'disadvantage disagree disappear disappoint disappointed disappointing disappointment disaster disc discipline discount discover',
    'discovery discuss discussion disease dishonest dislike dismiss display distance distribute distribution district',
    'divide division divorced document domestic dominate double doubt downstairs dramatic dramatically dream',
    'dress drop drug drunk dust duty eager earn earth economic economy edge',
    'editor effective effectively efficient effort election electric electrical electricity electronic element embarrassed',
    'embarrassing emergency emotion emotional emphasis emphasize employ employee employer employment encourage end',
    'enemy energy engage engineering enormous ensure entertain entertainment enthusiastic entire entirely environment',
    'environmental episode equal equally equipment error escape essential establish estimate event eventually',
    'evidence evil exact exactly examination excellent except exchange excitement excuse executive exhibition',
    'exist existence expect expectation expected expense experience experienced experiment expert explanation explode',
    'explore explosion export express expression extend extent external extra extraordinary extreme extremely',
    'facility factor fail failure fair fairly faith fall false familiar fancy far',
    'fascinating fashion fashionable fault fear feather feature fee feed female fence field',
    'fierce fight figure file fill final financial finger fire firm fit fix',
    'flag flame flash flat flexible flood flow focus force forecast formal former',
    'fortunate fortune forward found foundation frame freeze frequently frighten frightened fuel fully',
    'function fund fundamental funeral fur furniture further gain gallery gap gas gate',
    'gather general generally generate generation generous gentle gentleman ghost giant global goal',
    'god gold govern government governor grab grade gradually grain grand grant grass',
    'grateful grave ground growth guarantee guard guess guest guide guilty gun guy',
    'might shall whether',
  ];

  static const List<String> _b2Chunks = [
    'abandon absorb abstract abuse accent acceptable accurate accuse achieve acknowledge acquire actual',
    'adapt additional adequate adjust administration admiration admire adopt advocate affair affect affection',
    'aggressive aide alarm album alien align allege allocate allowance ally alter alternative',
    'ambition ambitious amend analyse analysis analyst ancestor animate anniversary annual anonymous anticipate',
    'anxiety apology apparent appeal applaud applicable applicant application appoint appraisal approach approval',
    'approximate arbitrary archive arise armed array arson articulate artificial artistic aside assemble',
    'assembly assert assess assessment asset assign assistance associate association assume assumption assurance',
    'assure astonish attachment attain attribute authentic authorise automate automatic avail avenue avert',
    'await awareness awkward banned barrier benchmark bias bitterness breakthrough capacity coherent collapse',
    'colleague commence commission committee commodity compatible compensate competent compile comply component compound',
    'compounds comprehend comprehensive comprise compromise conceive concurrent conform consensus consent consequent conservation',
    'considerable consistent consolidate constitute constrain consult consume contemporary contradict contribute controversial convert',
    'convey convict coordinate correspond crucial cumulative currency deficiency deficit deliberately denote depict',
    'derive deteriorate deviate differentiate diminish discrete discriminate displace disposition disrupt distinct distinguish',
    'distort diverge diverse domain dominant dynamic eliminate emerge empirical enable encounter enhance',
    'entity environments equate equilibrium equivalent erode escalate estate ethic ethnic evaluate evident',
    'evolve exceed exclude exemplify exert exhibit expand explicit exploit expose extract facilitate',
    'feasible fluctuate formula forthcoming foster framework genetic genetics hierarchy highlight hypothesis identical',
    'identify ideology illustrate impact implement implication implicit imply impose incentive incidence incline',
    'income inconvenient incorporate index indicate individual induce inevitable infer infrastructure inherent inhibit',
    'initial initiate injure innovate innovative input insensitive insert insight inspect instance institute',
    'instruct integral integrate integrity intelligence intense interact intermediate internal interpret intervene intrinsic',
    'invest investigate invoke involve isolate issue item job journal justify label labour',
    'layer lecture legal legislate levy liberal license likewise link locate logic maintain',
    'major majority manifest manipulate manual margin mature maximise mechanism media mediate medical',
    'medium mental method migrate military minimal minimise minimum ministry minor mode modify',
    'monitor motive mutual negate network neutral nevertheless nonetheless norm normal notion nuclear',
    'objective obtain obvious occupy occur odd offset ongoing option orient outcome output',
    'overall overlap overseas panel paradigm paragraph parallel parameter participate partner passive perceive',
    'percent period persist perspective phase phenomenon philosophy physical plus policy portion pose',
    'positive potential practitioner precede precise predict predominant preliminary presume previous primary prime',
    'principal principle prior priority proceed process professional prohibit promote proportion prospect protocol',
    'psychology publication publish purchase pursue qualitative quote radical random range ratio rational',
    'react recover refine regime region register regulate reinforce reject relax release relevant',
    'reluctance rely remove require research reside resolve resource respond restore restrain restrict',
    'retain reveal revenue reverse revise revolution rigid role route scenario schedule scheme',
    'scope section sector secure seek select sensitive sensitivity sequence series shift significant',
    'simulate site so-called sole somewhat source specific specify sphere stable statistic status',
    'straightforward strategy stress structure style submit subordinate subsequent subsidiary substantially substitute successor',
    'sufficient sum summary supplement survey survive suspend sustain symbol tape target task',
    'technical technique technology temporary tense terminate theme theory thereby thesis topic trace',
    'tradition transfer transform transit transmit transport trend trigger ultimate undergo underlie undertake',
    'unify unique utilise valid vary vehicle version via violate virtual visible vision',
    'visual volume voluntary welfare whereas whereby widespread',
  ];

  static const List<String> _c1Chunks = [
    'ambivalent anomalous clandestine conundrum detrimental dichotomy disparity dogmatic eccentric eloquent ephemeral esoteric',
    'exacerbate facet fastidious geneticist gregarious idiosyncratic imperative indigenous juxtapose lucid meticulous mitigate',
    'negligible nuance obstinate paradoxical pragmatic profound quandary resilient scrutiny shun substantiate surreptitious',
    'tangible tenacious ubiquitous ubiquity unprecedented unravel vacillate viable whimsical xenophobia zeal zenith',
  ];

  static const List<String> _c2Chunks = [
    'aberration alacrity anachronism antipathy approbation arduous assiduous audacious austere bellicose cacophony capricious',
    'castigate circumspect cogent corroborate cruciferous deleterious demagogue diatribe dilatory disparate ebullient effrontery',
    'enervate equivocal erudite exculpate facetious garrulous harangue hegemony iconoclast implacable inchoate indolent',
    'inimical intransigent laconic magnanimous maverick mendacious nefarious obdurate obsequious ostentatious parsimonious pedantic',
    'perfunctory pernicious precocious proclivity recalcitrant sagacious salient sanguine spurious taciturn venerate vociferous',
    'zeitgeist',
  ];

  static final Map<String, String> wordToCefr = _buildWordMap();

  static Map<String, String> _buildWordMap() {
    final map = <String, String>{};
    void addChunks(List<String> chunks, String level) {
      for (final chunk in chunks) {
        for (final w in chunk.split(' ')) {
          if (w.isNotEmpty) map[w] = level;
        }
      }
    }

    addChunks(_a1Chunks, 'A1');
    addChunks(_a2Chunks, 'A2');
    addChunks(_b1Chunks, 'B1');
    addChunks(_b2Chunks, 'B2');
    addChunks(_c1Chunks, 'C1');
    addChunks(_c2Chunks, 'C2');
    return map;
  }

  /// Returns the CEFR level for a lemma. Defaults to null if not catalogued.
  static String? lookupCefr(String lemma) {
    final clean = lemma.toLowerCase().trim();
    return wordToCefr[clean];
  }

  /// Maps word to frequency band (K1: 1-1000, K2: 1001-2000, K3: 2001-3000, K4+: 3001+, Off-list)
  static String getFrequencyBand(String lemma, String cefrLevel) {
    if (cefrLevel == 'A1') return 'K1';
    if (cefrLevel == 'A2') return 'K1';
    if (cefrLevel == 'B1') return 'K2';
    if (cefrLevel == 'B2') return 'K3';
    if (cefrLevel == 'C1' || cefrLevel == 'C2') return 'K4+';
    if (academicWordList.contains(lemma)) return 'K3';
    return 'Off-list';
  }
}
