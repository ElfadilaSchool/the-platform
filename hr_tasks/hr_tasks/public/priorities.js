import React, { useState, useEffect } from 'react';
import { Search, Filter, AlertTriangle, Clock, CheckCircle, Bell, TrendingUp, TrendingDown, ChevronDown, ChevronUp, Eye, Archive, Share2, Calendar, User, Building, Tag, Zap } from 'lucide-react';

const DirectorDashboard = () => {
  const [reports, setReports] = useState([]);
  const [filter, setFilter] = useState('all');
  const [searchTerm, setSearchTerm] = useState('');
  const [expandedSection, setExpandedSection] = useState({ critical: true, veryHigh: true, moderate: true, low: false });
  const [selectedReport, setSelectedReport] = useState(null);
  const [loading, setLoading] = useState(true);

  // Données simulées (remplacer par fetch API)
  useEffect(() => {
    // Simulation de chargement
    setTimeout(() => {
      setReports(mockReports);
      setLoading(false);
    }, 1000);
  }, []);

  const mockReports = [
    {
      id: '1',
      title: 'حادث عنف جسدي في الورشة',
      subject: 'صراع بين موظفين',
      content: 'وقع صراع خطير بين موظفين في الورشة ب. تم استخدام العنف الجسدي. يوجد شهود على الحادث.',
      employee: { name: 'Ahmed Benali', department: 'الإنتاج' },
      created_at: '2025-10-08T14:30:00',
      status: 'pending',
      analysis: {
        summary: 'تم اكتشاف حالة عنف جسدي خطيرة بين موظفين في الورشة مع وجود شهود. الوضع يتطلب تدخل فوري.',
        sentiment: { label: 'سلبي', score: 0.92 },
        severity: { score: 10, level: 'حرجة للغاية', levelFr: 'critique absolu', source: 'dictionary_override' },
        urgency: { score: 10, level: 'حرج جدا', levelFr: 'urgence maximale' },
        keywords: ['عنف', 'صراع', 'خطير', 'شهود', 'ورشة'],
        entities: { persons: ['أحمد بن علي', 'كريم منصوري'], locations: ['الورشة ب'], dates: ['08/10/2025'] },
        categories: ['عنف جسدي', 'طوارئ'],
        analysis_method: { fusion_strategy: 'dictionary_override', dictionary_keywords_count: 5 }
      }
    },
    {
      id: '2',
      title: 'تهديدات لفظية من مسؤول',
      subject: 'سوء معاملة',
      content: 'تعرضت لتهديدات لفظية متكررة من المسؤول المباشر. الوضع يؤثر على صحتي النفسية.',
      employee: { name: 'Fatima Zahra', department: 'الموارد البشرية' },
      created_at: '2025-10-08T10:15:00',
      status: 'pending',
      analysis: {
        summary: 'تقرير عن تهديدات لفظية متكررة من مسؤول مباشر تؤثر على الصحة النفسية للموظف.',
        sentiment: { label: 'سلبي', score: 0.85 },
        severity: { score: 8, level: 'عالية جدا', levelFr: 'très élevée', source: 'hybrid' },
        urgency: { score: 8, level: 'عالي جدا', levelFr: 'très urgent' },
        keywords: ['تهديدات', 'لفظية', 'مسؤول', 'نفسية', 'متكررة'],
        entities: { persons: ['فاطمة الزهراء'], locations: [], dates: [] },
        categories: ['تهديد', 'صحة نفسية'],
        analysis_method: { fusion_strategy: 'weighted_hybrid', dictionary_keywords_count: 3 }
      }
    },
    {
      id: '3',
      title: 'طلب إجازة استثنائية',
      subject: 'ظرف عائلي طارئ',
      content: 'أطلب إجازة استثنائية لمدة ثلاثة أيام بسبب ظرف عائلي طارئ. والدتي في المستشفى.',
      employee: { name: 'Karim Mansouri', department: 'المالية' },
      created_at: '2025-10-08T09:00:00',
      status: 'pending',
      analysis: {
        summary: 'طلب إجازة استثنائية لثلاثة أيام بسبب حالة صحية طارئة لوالدة الموظف.',
        sentiment: { label: 'محايد', score: 0.55 },
        severity: { score: 5, level: 'متوسطة', levelFr: 'moyenne', source: 'ai_only' },
        urgency: { score: 6, level: 'متوسط', levelFr: 'modéré' },
        keywords: ['إجازة', 'طارئ', 'عائلي', 'مستشفى'],
        entities: { persons: ['كريم منصوري'], locations: ['المستشفى'], dates: [] },
        categories: ['إجازة', 'ظرف عائلي'],
        analysis_method: { fusion_strategy: 'ai_only', dictionary_keywords_count: 0 }
      }
    },
    {
      id: '4',
      title: 'اقتراح تحسين الإجراءات',
      subject: 'تطوير نظام الحضور',
      content: 'أقترح تطوير نظام الحضور الحالي لتحسين الكفاءة وتقليل الأخطاء.',
      employee: { name: 'Yassine Alami', department: 'تكنولوجيا المعلومات' },
      created_at: '2025-10-07T16:45:00',
      status: 'acknowledged',
      analysis: {
        summary: 'اقتراح بناء لتطوير نظام الحضور الإلكتروني لزيادة الكفاءة.',
        sentiment: { label: 'إيجابي', score: 0.78 },
        severity: { score: 2, level: 'منخفضة', levelFr: 'faible', source: 'ai_only' },
        urgency: { score: 3, level: 'منخفض', levelFr: 'faible' },
        keywords: ['اقتراح', 'تحسين', 'نظام', 'كفاءة'],
        entities: { persons: [], locations: [], dates: [] },
        categories: ['اقتراح', 'تطوير'],
        analysis_method: { fusion_strategy: 'ai_only', dictionary_keywords_count: 0 }
      }
    },
    {
      id: '5',
      title: 'تقرير عن حادث عمل بسيط',
      subject: 'إصابة طفيفة',
      content: 'تعرض أحد الموظفين لإصابة طفيفة في اليد أثناء العمل. تم تقديم الإسعافات الأولية.',
      employee: { name: 'Mohamed Tazi', department: 'الإنتاج' },
      created_at: '2025-10-07T11:20:00',
      status: 'acknowledged',
      analysis: {
        summary: 'تقرير عن إصابة عمل طفيفة تم التعامل معها بالإسعافات الأولية.',
        sentiment: { label: 'محايد', score: 0.50 },
        severity: { score: 4, level: 'متوسطة', levelFr: 'moyenne', source: 'weighted_hybrid' },
        urgency: { score: 4, level: 'متوسط', levelFr: 'modéré' },
        keywords: ['حادث', 'إصابة', 'طفيفة', 'إسعافات'],
        entities: { persons: [], locations: [], dates: [] },
        categories: ['حادث عمل', 'صحة'],
        analysis_method: { fusion_strategy: 'weighted_hybrid', dictionary_keywords_count: 1 }
      }
    }
  ];

  // Fonction pour catégoriser les rapports
  const categorizeReports = () => {
    const categories = {
      critical: reports.filter(r => r.analysis.severity.score >= 9),
      veryHigh: reports.filter(r => r.analysis.severity.score >= 7 && r.analysis.severity.score < 9),
      moderate: reports.filter(r => r.analysis.severity.score >= 4 && r.analysis.severity.score < 7),
      low: reports.filter(r => r.analysis.severity.score < 4)
    };
    return categories;
  };

  const categorized = categorizeReports();

  // Calcul des statistiques
  const stats = {
    critical: categorized.critical.length,
    veryHigh: categorized.veryHigh.length,
    moderate: categorized.moderate.length,
    low: categorized.low.length
  };

  // Fonction pour formater la date
  const formatDate = (dateString) => {
    const date = new Date(dateString);
    const now = new Date();
    const diff = Math.floor((now - date) / 1000 / 60); // minutes
    
    if (diff < 1) return 'À l\'instant';
    if (diff < 60) return `Il y a ${diff} min`;
    if (diff < 1440) return `Il y a ${Math.floor(diff / 60)}h`;
    return date.toLocaleDateString('fr-FR', { day: '2-digit', month: '2-digit', year: 'numeric' });
  };

  // Composant Badge Gravité
  const SeverityBadge = ({ score, level }) => {
    const getColor = () => {
      if (score >= 9) return 'bg-red-900 text-white border-red-950';
      if (score >= 7) return 'bg-red-500 text-white border-red-600';
      if (score >= 4) return 'bg-yellow-500 text-white border-yellow-600';
      return 'bg-green-500 text-white border-green-600';
    };

    const getIcon = () => {
      if (score >= 9) return <Zap className="w-3 h-3" />;
      if (score >= 7) return <AlertTriangle className="w-3 h-3" />;
      if (score >= 4) return <Clock className="w-3 h-3" />;
      return <CheckCircle className="w-3 h-3" />;
    };

    return (
      <span className={`inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-bold border-2 ${getColor()}`}>
        {getIcon()}
        {score}/10
      </span>
    );
  };

  // Composant Carte Rapport
  const ReportCard = ({ report, severity }) => {
    const getBgColor = () => {
      if (severity === 'critical') return 'bg-red-50 border-red-600 shadow-red-200';
      if (severity === 'veryHigh') return 'bg-red-100 border-red-400 shadow-red-100';
      if (severity === 'moderate') return 'bg-yellow-50 border-yellow-500 shadow-yellow-100';
      return 'bg-green-50 border-green-500 shadow-green-100';
    };

    const getPulse = () => severity === 'critical' ? 'animate-pulse' : '';

    return (
      <div 
        className={`${getBgColor()} border-l-4 rounded-lg p-4 mb-3 hover:shadow-lg transition-all cursor-pointer ${getPulse()}`}
        onClick={() => setSelectedReport(report)}
      >
        {/* Header */}
        <div className="flex items-start justify-between mb-3">
          <div className="flex items-center gap-2">
            <SeverityBadge score={report.analysis.severity.score} level={report.analysis.severity.level} />
            {report.status === 'pending' && (
              <span className="relative flex h-3 w-3">
                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-red-400 opacity-75"></span>
                <span className="relative inline-flex rounded-full h-3 w-3 bg-red-500"></span>
              </span>
            )}
          </div>
          <span className="text-xs text-gray-500">{formatDate(report.created_at)}</span>
        </div>

        {/* Titre et Sujet */}
        <div className="mb-3">
          <h3 className="font-bold text-lg mb-1 text-gray-900">{report.title}</h3>
          <p className="text-sm text-gray-600 flex items-center gap-1">
            <Tag className="w-3 h-3" />
            {report.subject}
          </p>
        </div>

        {/* Résumé IA */}
        <div className="bg-white bg-opacity-60 rounded-md p-3 mb-3">
          <p className="text-sm text-gray-800 leading-relaxed" dir="rtl">
            📝 {report.analysis.summary}
          </p>
        </div>

        {/* Mots-clés */}
        <div className="flex flex-wrap gap-1 mb-3">
          {report.analysis.keywords.slice(0, 5).map((keyword, idx) => (
            <span key={idx} className="bg-gray-200 text-gray-700 px-2 py-0.5 rounded text-xs">
              {keyword}
            </span>
          ))}
        </div>

        {/* Entités */}
        {(report.analysis.entities.persons.length > 0 || report.analysis.entities.locations.length > 0) && (
          <div className="text-xs text-gray-600 mb-3 space-y-1">
            {report.analysis.entities.persons.length > 0 && (
              <div className="flex items-center gap-1">
                <User className="w-3 h-3" />
                <span>{report.analysis.entities.persons.join(', ')}</span>
              </div>
            )}
            {report.analysis.entities.locations.length > 0 && (
              <div className="flex items-center gap-1">
                <Building className="w-3 h-3" />
                <span>{report.analysis.entities.locations.join(', ')}</span>
              </div>
            )}
          </div>
        )}

        {/* Sentiment et Infos */}
        <div className="flex items-center justify-between text-xs text-gray-600">
          <div className="flex items-center gap-3">
            <span>😊 {report.analysis.sentiment.label} ({Math.round(report.analysis.sentiment.score * 100)}%)</span>
            <span>⏰ Urgence: {report.analysis.urgency.score}/10</span>
          </div>
          <div className="flex items-center gap-1">
            <User className="w-3 h-3" />
            <span>{report.employee.name}</span>
          </div>
        </div>

        {/* Actions */}
        <div className="flex gap-2 mt-3 pt-3 border-t border-gray-300">
          <button className="flex-1 bg-blue-600 hover:bg-blue-700 text-white text-xs py-2 rounded-md flex items-center justify-center gap-1 transition">
            <Eye className="w-3 h-3" />
            Voir Détails
          </button>
          <button className="bg-gray-200 hover:bg-gray-300 text-gray-700 text-xs py-2 px-3 rounded-md transition">
            <Archive className="w-4 h-4" />
          </button>
          <button className="bg-gray-200 hover:bg-gray-300 text-gray-700 text-xs py-2 px-3 rounded-md transition">
            <Share2 className="w-4 h-4" />
          </button>
        </div>
      </div>
    );
  };

  // Section de rapports
  const ReportSection = ({ title, icon, reports, severity, color }) => {
    const isExpanded = expandedSection[severity];

    return (
      <div className="mb-6">
        <button
          onClick={() => setExpandedSection({ ...expandedSection, [severity]: !isExpanded })}
          className={`w-full flex items-center justify-between p-4 rounded-lg ${color} border-2 font-bold text-lg mb-3 hover:opacity-90 transition`}
        >
          <div className="flex items-center gap-2">
            {icon}
            <span>{title} ({reports.length})</span>
          </div>
          {isExpanded ? <ChevronUp /> : <ChevronDown />}
        </button>
        
        {isExpanded && (
          <div className="space-y-2">
            {reports.length === 0 ? (
              <div className="text-center py-8 text-gray-500">
                <CheckCircle className="w-12 h-12 mx-auto mb-2 text-green-500" />
                <p>Aucun rapport dans cette catégorie</p>
              </div>
            ) : (
              reports.map(report => (
                <ReportCard key={report.id} report={report} severity={severity} />
              ))
            )}
          </div>
        )}
      </div>
    );
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-gray-50 to-gray-100 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-16 w-16 border-b-2 border-blue-600 mx-auto mb-4"></div>
          <p className="text-gray-600">Chargement des rapports...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-50 to-gray-100">
      {/* Header */}
      <div className="bg-white shadow-md border-b-4 border-blue-600">
        <div className="max-w-7xl mx-auto px-4 py-6">
          <h1 className="text-3xl font-bold text-gray-900 mb-2">📊 Tableau de Bord Directeur</h1>
          <p className="text-gray-600">Gestion intelligente des rapports avec analyse IA</p>
        </div>
      </div>

      <div className="max-w-7xl mx-auto px-4 py-6">
        {/* KPI Cards */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
          {/* Critical */}
          <div className="bg-gradient-to-br from-red-900 to-red-800 text-white rounded-xl p-6 shadow-lg border-2 border-red-950">
            <div className="flex items-center justify-between mb-2">
              <Zap className="w-8 h-8" />
              <span className="text-4xl font-bold">{stats.critical}</span>
            </div>
            <p className="text-red-100 font-semibold">CRITIQUES</p>
            <p className="text-xs text-red-200 mt-1">Action immédiate requise</p>
          </div>

          {/* Very High */}
          <div className="bg-gradient-to-br from-red-500 to-red-600 text-white rounded-xl p-6 shadow-lg">
            <div className="flex items-center justify-between mb-2">
              <AlertTriangle className="w-8 h-8" />
              <span className="text-4xl font-bold">{stats.veryHigh}</span>
            </div>
            <p className="text-red-50 font-semibold">TRÈS URGENT</p>
            <p className="text-xs text-red-100 mt-1">Traiter rapidement</p>
          </div>

          {/* Moderate */}
          <div className="bg-gradient-to-br from-yellow-500 to-yellow-600 text-white rounded-xl p-6 shadow-lg">
            <div className="flex items-center justify-between mb-2">
              <Clock className="w-8 h-8" />
              <span className="text-4xl font-bold">{stats.moderate}</span>
            </div>
            <p className="text-yellow-50 font-semibold">MODÉRÉS</p>
            <p className="text-xs text-yellow-100 mt-1">À traiter</p>
          </div>

          {/* Low */}
          <div className="bg-gradient-to-br from-green-500 to-green-600 text-white rounded-xl p-6 shadow-lg">
            <div className="flex items-center justify-between mb-2">
              <CheckCircle className="w-8 h-8" />
              <span className="text-4xl font-bold">{stats.low}</span>
            </div>
            <p className="text-green-50 font-semibold">FAIBLES</p>
            <p className="text-xs text-green-100 mt-1">Consultatif</p>
          </div>
        </div>

        {/* Filtres */}
        <div className="bg-white rounded-lg shadow-md p-4 mb-6">
          <div className="flex flex-wrap gap-3">
            <button className="flex items-center gap-2 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition">
              <Bell className="w-4 h-4" />
              Non lus critiques
            </button>
            <button className="flex items-center gap-2 px-4 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300 transition">
              <Calendar className="w-4 h-4" />
              Aujourd'hui
            </button>
            <button className="flex items-center gap-2 px-4 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300 transition">
              <Building className="w-4 h-4" />
              Par département
            </button>
            <div className="flex-1 min-w-[200px]">
              <div className="relative">
                <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400" />
                <input
                  type="text"
                  placeholder="Rechercher par mots-clés..."
                  className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                />
              </div>
            </div>
          </div>
        </div>

        {/* Rapports par catégorie */}
        <ReportSection
          title="RAPPORTS CRITIQUES"
          icon={<Zap className="w-6 h-6 text-red-950" />}
          reports={categorized.critical}
          severity="critical"
          color="bg-red-100 border-red-900 text-red-950"
        />

        <ReportSection
          title="TRÈS URGENT"
          icon={<AlertTriangle className="w-6 h-6 text-red-700" />}
          reports={categorized.veryHigh}
          severity="veryHigh"
          color="bg-red-50 border-red-500 text-red-700"
        />

        <ReportSection
          title="MODÉRÉS"
          icon={<Clock className="w-6 h-6 text-yellow-700" />}
          reports={categorized.moderate}
          severity="moderate"
          color="bg-yellow-50 border-yellow-500 text-yellow-700"
        />

        <ReportSection
          title="FAIBLE PRIORITÉ"
          icon={<CheckCircle className="w-6 h-6 text-green-700" />}
          reports={categorized.low}
          severity="low"
          color="bg-green-50 border-green-500 text-green-700"
        />
      </div>
    </div>
  );
};

export default DirectorDashboard;