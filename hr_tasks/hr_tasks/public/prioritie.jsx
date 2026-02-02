import React, { useState, useEffect, useMemo } from 'react';
import { AlertCircle, TrendingUp, Clock, Archive, Check, Filter, Search, Calendar, Users, MapPin, Building, User, Tag, ChevronDown, ChevronUp, Eye, Download, BarChart3, AlertTriangle, Info, X } from 'lucide-react';

const API_BASE = (location.origin && /^https?:\/\//i.test(location.origin)) ? (location.origin + '/api/rapportemp') : 'http://localhost:3020/api/rapportemp';

// Couleurs selon la gravité
const getSeverityColor = (score) => {
  if (score >= 9) return {
    bg: 'bg-red-50 border-red-200',
    text: 'text-red-900',
    badge: 'bg-red-600 text-white',
    border: 'border-l-4 border-l-red-600',
    glow: 'shadow-lg shadow-red-200',
    icon: 'text-red-600'
  };
  if (score >= 7) return {
    bg: 'bg-orange-50 border-orange-200',
    text: 'text-orange-900',
    badge: 'bg-orange-500 text-white',
    border: 'border-l-4 border-l-orange-500',
    glow: 'shadow-lg shadow-orange-200',
    icon: 'text-orange-500'
  };
  if (score >= 5) return {
    bg: 'bg-yellow-50 border-yellow-200',
    text: 'text-yellow-900',
    badge: 'bg-yellow-500 text-white',
    border: 'border-l-4 border-l-yellow-500',
    glow: 'shadow-md shadow-yellow-200',
    icon: 'text-yellow-500'
  };
  if (score >= 3) return {
    bg: 'bg-blue-50 border-blue-200',
    text: 'text-blue-900',
    badge: 'bg-blue-500 text-white',
    border: 'border-l-4 border-l-blue-500',
    glow: 'shadow-md shadow-blue-200',
    icon: 'text-blue-500'
  };
  return {
    bg: 'bg-gray-50 border-gray-200',
    text: 'text-gray-900',
    badge: 'bg-gray-500 text-white',
    border: 'border-l-4 border-l-gray-500',
    glow: 'shadow-sm shadow-gray-200',
    icon: 'text-gray-500'
  };
};

const DirectorDashboard = () => {
  const [reports, setReports] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [severityFilter, setSeverityFilter] = useState('all');
  const [categoryFilter, setCategoryFilter] = useState('all');
  const [view, setView] = useState('recent'); // 'recent' ou 'archived'
  const [selectedReport, setSelectedReport] = useState(null);

  // Récupération des rapports depuis l'API
  useEffect(() => {
    fetchReports();
  }, []);

  const fetchReports = async () => {
    try {
      setLoading(true);
      const response = await fetch(API_BASE);
      const data = await response.json();
      
      // Filtrer les rapports avec analyse
      const reportsWithAnalysis = data.reports.filter(r => r.analysis);
      setReports(reportsWithAnalysis);
    } catch (error) {
      console.error('Erreur chargement rapports:', error);
    } finally {
      setLoading(false);
    }
  };

  // Marquer un rapport comme traité
  const markAsProcessed = async (reportId) => {
    try {
      await fetch(`${API_BASE}/${reportId}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status: 'acknowledged' })
      });
      
      setReports(prev => prev.map(r => 
        r.id === reportId ? { ...r, status: 'acknowledged' } : r
      ));
    } catch (error) {
      console.error('Erreur marquage rapport:', error);
    }
  };

  // Filtrage et tri des rapports
  const filteredReports = useMemo(() => {
    let filtered = reports.filter(report => {
      const analysis = report.analysis;
      const matchesView = view === 'recent' 
        ? report.status === 'pending' 
        : report.status === 'acknowledged';
      
      const matchesSearch = !searchTerm || 
        report.title.toLowerCase().includes(searchTerm.toLowerCase()) ||
        report.subject.toLowerCase().includes(searchTerm.toLowerCase()) ||
        analysis.summary?.toLowerCase().includes(searchTerm.toLowerCase());
      
      const matchesSeverity = severityFilter === 'all' || 
        (severityFilter === 'critical' && analysis.severity?.score >= 9) ||
        (severityFilter === 'high' && analysis.severity?.score >= 7 && analysis.severity?.score < 9) ||
        (severityFilter === 'medium' && analysis.severity?.score >= 4 && analysis.severity?.score < 7) ||
        (severityFilter === 'low' && analysis.severity?.score < 4);
      
      const matchesCategory = categoryFilter === 'all' || 
        analysis.categories?.some(cat => cat.includes(categoryFilter));
      
      return matchesView && matchesSearch && matchesSeverity && matchesCategory;
    });

    // Tri par score de gravité décroissant
    return filtered.sort((a, b) => {
      const scoreA = a.analysis.severity?.score || 0;
      const scoreB = b.analysis.severity?.score || 0;
      return scoreB - scoreA;
    });
  }, [reports, searchTerm, severityFilter, categoryFilter, view]);

  // Statistiques
  const stats = useMemo(() => {
    const pending = reports.filter(r => r.status === 'pending');
    return {
      total: reports.length,
      pending: pending.length,
      critical: pending.filter(r => r.analysis.severity?.score >= 9).length,
      high: pending.filter(r => r.analysis.severity?.score >= 7 && r.analysis.severity?.score < 9).length,
      medium: pending.filter(r => r.analysis.severity?.score >= 4 && r.analysis.severity?.score < 7).length,
      low: pending.filter(r => r.analysis.severity?.score < 4).length,
      archived: reports.filter(r => r.status === 'acknowledged').length
    };
  }, [reports]);

  // Catégories uniques
  const categories = useMemo(() => {
    const cats = new Set();
    reports.forEach(r => {
      r.analysis.categories?.forEach(cat => cats.add(cat));
    });
    return Array.from(cats);
  }, [reports]);

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-slate-50 to-slate-100 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-16 w-16 border-4 border-blue-500 border-t-transparent mx-auto mb-4"></div>
          <p className="text-slate-600 font-medium">جاري تحميل التقارير...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-50 via-blue-50 to-slate-100" dir="rtl">
      {/* Header */}
      <div className="bg-white border-b border-slate-200 shadow-sm sticky top-0 z-40">
        <div className="max-w-7xl mx-auto px-6 py-4">
          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-2xl font-bold text-slate-900 flex items-center gap-3">
                <BarChart3 className="text-blue-600" size={32} />
                لوحة التحكم - تحليل التقارير
              </h1>
              <p className="text-sm text-slate-600 mt-1">نظام الذكاء الاصطناعي لتحليل التقارير وترتيب الأولويات</p>
            </div>
            <div className="flex gap-3">
              <button
                onClick={() => setView('recent')}
                className={`px-6 py-2.5 rounded-lg font-medium transition-all ${
                  view === 'recent'
                    ? 'bg-blue-600 text-white shadow-lg shadow-blue-200'
                    : 'bg-slate-100 text-slate-700 hover:bg-slate-200'
                }`}
              >
                <Clock className="inline ml-2" size={18} />
                التقارير الحالية ({stats.pending})
              </button>
              <button
                onClick={() => setView('archived')}
                className={`px-6 py-2.5 rounded-lg font-medium transition-all ${
                  view === 'archived'
                    ? 'bg-blue-600 text-white shadow-lg shadow-blue-200'
                    : 'bg-slate-100 text-slate-700 hover:bg-slate-200'
                }`}
              >
                <Archive className="inline ml-2" size={18} />
                المعالجة ({stats.archived})
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* Stats Cards */}
      <div className="max-w-7xl mx-auto px-6 py-6">
        <div className="grid grid-cols-5 gap-4 mb-6">
          <StatCard
            title="حرجة للغاية"
            count={stats.critical}
            icon={AlertTriangle}
            color="red"
          />
          <StatCard
            title="عالية جداً"
            count={stats.high}
            icon={AlertCircle}
            color="orange"
          />
          <StatCard
            title="متوسطة"
            count={stats.medium}
            icon={Info}
            color="yellow"
          />
          <StatCard
            title="منخفضة"
            count={stats.low}
            icon={Check}
            color="blue"
          />
          <StatCard
            title="المجموع"
            count={stats.total}
            icon={BarChart3}
            color="slate"
          />
        </div>

        {/* Filtres */}
        <div className="bg-white rounded-xl shadow-sm border border-slate-200 p-4 mb-6">
          <div className="grid grid-cols-3 gap-4">
            <div className="relative">
              <Search className="absolute right-3 top-3 text-slate-400" size={20} />
              <input
                type="text"
                placeholder="بحث في التقارير..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pr-10 pl-4 py-2.5 border border-slate-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              />
            </div>

            <select
              value={severityFilter}
              onChange={(e) => setSeverityFilter(e.target.value)}
              className="px-4 py-2.5 border border-slate-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            >
              <option value="all">كل المستويات</option>
              <option value="critical">حرجة للغاية (9-10)</option>
              <option value="high">عالية (7-8)</option>
              <option value="medium">متوسطة (4-6)</option>
              <option value="low">منخفضة (1-3)</option>
            </select>

            <select
              value={categoryFilter}
              onChange={(e) => setCategoryFilter(e.target.value)}
              className="px-4 py-2.5 border border-slate-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            >
              <option value="all">كل الفئات</option>
              {categories.map(cat => (
                <option key={cat} value={cat}>{cat}</option>
              ))}
            </select>
          </div>
        </div>

        {/* Liste des rapports */}
        <div className="space-y-4">
          {filteredReports.length === 0 ? (
            <div className="bg-white rounded-xl shadow-sm border border-slate-200 p-12 text-center">
              <Archive className="mx-auto mb-4 text-slate-300" size={64} />
              <p className="text-slate-600 text-lg">لا توجد تقارير</p>
            </div>
          ) : (
            filteredReports.map(report => (
              <ReportCard
                key={report.id}
                report={report}
                onMarkProcessed={markAsProcessed}
                onViewDetails={setSelectedReport}
              />
            ))
          )}
        </div>
      </div>

      {/* Modal détails */}
      {selectedReport && (
        <ReportModal
          report={selectedReport}
          onClose={() => setSelectedReport(null)}
          onMarkProcessed={markAsProcessed}
        />
      )}
    </div>
  );
};

// Composant Carte Statistique
const StatCard = ({ title, count, icon: Icon, color }) => {
  const colors = {
    red: 'bg-red-500 text-white',
    orange: 'bg-orange-500 text-white',
    yellow: 'bg-yellow-500 text-white',
    blue: 'bg-blue-500 text-white',
    slate: 'bg-slate-700 text-white'
  };

  return (
    <div className="bg-white rounded-xl shadow-sm border border-slate-200 p-4 hover:shadow-md transition-shadow">
      <div className="flex items-center justify-between">
        <div>
          <p className="text-sm text-slate-600 mb-1">{title}</p>
          <p className="text-3xl font-bold text-slate-900">{count}</p>
        </div>
        <div className={`p-3 rounded-lg ${colors[color]}`}>
          <Icon size={24} />
        </div>
      </div>
    </div>
  );
};

// Composant Carte Rapport
const ReportCard = ({ report, onMarkProcessed, onViewDetails }) => {
  const analysis = report.analysis;
  const severityScore = analysis.severity?.score || 0;
  const urgencyScore = analysis.urgency?.score || 0;
  const colors = getSeverityColor(Math.max(severityScore, urgencyScore));

  return (
    <div className={`bg-white rounded-xl shadow-sm border ${colors.border} ${colors.bg} ${colors.glow} hover:shadow-xl transition-all duration-300 overflow-hidden`}>
      <div className="p-6">
        {/* Catégorie */}
        {analysis.categories && analysis.categories.length > 0 && (
          <div className="flex items-center gap-2 mb-4">
            <div className="h-px flex-1 bg-slate-300"></div>
            <span className={`px-4 py-1 rounded-full text-sm font-bold ${colors.badge}`}>
              {analysis.categories[0]}
            </span>
            <div className="h-px flex-1 bg-slate-300"></div>
          </div>
        )}

        {/* Titre */}
        <h3 className={`text-xl font-bold mb-3 ${colors.text}`}>
          {report.title}
        </h3>

        {/* Résumé */}
        <p className="text-slate-700 mb-4 leading-relaxed text-base">
          {analysis.summary}
        </p>

        {/* Mots-clés */}
        {analysis.keywords && analysis.keywords.length > 0 && (
          <div className="flex flex-wrap gap-2 mb-4">
            <Tag className="text-slate-400" size={16} />
            {analysis.keywords.slice(0, 8).map((keyword, idx) => (
              <span
                key={idx}
                className="px-3 py-1 bg-slate-100 text-slate-700 rounded-full text-sm font-medium border border-slate-200"
              >
                {keyword}
              </span>
            ))}
          </div>
        )}

        {/* Entités */}
        <div className="grid grid-cols-2 gap-3 mb-4 text-sm">
          {analysis.entities?.persons && analysis.entities.persons.length > 0 && (
            <div className="flex items-start gap-2">
              <User className="text-blue-500 mt-0.5" size={16} />
              <div>
                <p className="font-medium text-slate-600 mb-1">الأشخاص:</p>
                <p className="text-slate-700">{analysis.entities.persons.join('، ')}</p>
              </div>
            </div>
          )}
          {analysis.entities?.locations && analysis.entities.locations.length > 0 && (
            <div className="flex items-start gap-2">
              <MapPin className="text-green-500 mt-0.5" size={16} />
              <div>
                <p className="font-medium text-slate-600 mb-1">الأماكن:</p>
                <p className="text-slate-700">{analysis.entities.locations.join('، ')}</p>
              </div>
            </div>
          )}
          {analysis.entities?.organizations && analysis.entities.organizations.length > 0 && (
            <div className="flex items-start gap-2">
              <Building className="text-purple-500 mt-0.5" size={16} />
              <div>
                <p className="font-medium text-slate-600 mb-1">المؤسسات:</p>
                <p className="text-slate-700">{analysis.entities.organizations.join('، ')}</p>
              </div>
            </div>
          )}
          {analysis.entities?.dates && analysis.entities.dates.length > 0 && (
            <div className="flex items-start gap-2">
              <Calendar className="text-orange-500 mt-0.5" size={16} />
              <div>
                <p className="font-medium text-slate-600 mb-1">التواريخ:</p>
                <p className="text-slate-700">{analysis.entities.dates.join('، ')}</p>
              </div>
            </div>
          )}
        </div>

        {/* Footer avec scores et bouton */}
        <div className="flex items-center justify-between pt-4 border-t border-slate-200">
          <div className="flex gap-4">
            <div className="text-center">
              <p className="text-xs text-slate-600 mb-1">الخطورة</p>
              <div className={`px-4 py-1.5 rounded-lg font-bold text-lg ${colors.badge}`}>
                {severityScore}/10
              </div>
            </div>
            <div className="text-center">
              <p className="text-xs text-slate-600 mb-1">الاستعجال</p>
              <div className={`px-4 py-1.5 rounded-lg font-bold text-lg ${colors.badge}`}>
                {urgencyScore}/10
              </div>
            </div>
            <div className="text-center">
              <p className="text-xs text-slate-600 mb-1">التاريخ</p>
              <div className="px-4 py-1.5 rounded-lg bg-slate-100 font-medium text-sm text-slate-700">
                {new Date(report.created_at).toLocaleDateString('ar-DZ')}
              </div>
            </div>
          </div>

          <div className="flex gap-2">
            <button
              onClick={() => onViewDetails(report)}
              className="px-6 py-2.5 bg-slate-100 hover:bg-slate-200 text-slate-700 rounded-lg font-medium transition-colors flex items-center gap-2"
            >
              <Eye size={18} />
              عرض التفاصيل
            </button>
            {report.status === 'pending' && (
              <button
                onClick={() => onMarkProcessed(report.id)}
                className="px-6 py-2.5 bg-green-600 hover:bg-green-700 text-white rounded-lg font-medium transition-colors flex items-center gap-2 shadow-lg shadow-green-200"
              >
                <Check size={18} />
                تم المعالجة
              </button>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

// Modal Détails Rapport
const ReportModal = ({ report, onClose, onMarkProcessed }) => {
  const analysis = report.analysis;
  const severityScore = analysis.severity?.score || 0;
  const colors = getSeverityColor(severityScore);

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4" onClick={onClose}>
      <div className={`bg-white rounded-2xl shadow-2xl max-w-4xl w-full max-h-[90vh] overflow-y-auto ${colors.border}`} onClick={(e) => e.stopPropagation()} dir="rtl">
        <div className={`${colors.bg} p-6 border-b border-slate-200 sticky top-0 z-10`}>
          <div className="flex items-center justify-between">
            <h2 className={`text-2xl font-bold ${colors.text}`}>{report.title}</h2>
            <button onClick={onClose} className="p-2 hover:bg-white/50 rounded-lg transition-colors">
              <X size={24} />
            </button>
          </div>
        </div>

        <div className="p-6 space-y-6">
          {/* Scores */}
          <div className="grid grid-cols-3 gap-4">
            <div className={`p-4 rounded-xl ${colors.bg} border ${colors.border.replace('border-l-4', 'border')}`}>
              <p className="text-sm text-slate-600 mb-2">مستوى الخطورة</p>
              <p className={`text-4xl font-bold ${colors.text}`}>{severityScore}/10</p>
              <p className="text-sm text-slate-600 mt-1">{analysis.severity?.level}</p>
            </div>
            <div className={`p-4 rounded-xl ${colors.bg} border ${colors.border.replace('border-l-4', 'border')}`}>
              <p className="text-sm text-slate-600 mb-2">مستوى الاستعجال</p>
              <p className={`text-4xl font-bold ${colors.text}`}>{analysis.urgency?.score}/10</p>
              <p className="text-sm text-slate-600 mt-1">{analysis.urgency?.level}</p>
            </div>
            <div className="p-4 rounded-xl bg-slate-50 border border-slate-200">
              <p className="text-sm text-slate-600 mb-2">المشاعر</p>
              <p className="text-2xl font-bold text-slate-900">{analysis.sentiment?.label}</p>
              <p className="text-sm text-slate-600 mt-1">{(analysis.sentiment?.score * 100).toFixed(0)}%</p>
            </div>
          </div>

          {/* Résumé */}
          <div>
            <h3 className="text-lg font-bold text-slate-900 mb-3">📄 الملخص</h3>
            <p className="text-slate-700 leading-relaxed bg-slate-50 p-4 rounded-lg">{analysis.summary}</p>
          </div>

          {/* Contenu complet */}
          <div>
            <h3 className="text-lg font-bold text-slate-900 mb-3">📝 المحتوى الكامل</h3>
            <div className="text-slate-700 leading-relaxed bg-slate-50 p-4 rounded-lg whitespace-pre-wrap">
              {report.content}
            </div>
          </div>

          {/* Catégories et Mots-clés */}
          <div className="grid grid-cols-2 gap-4">
            {analysis.categories && analysis.categories.length > 0 && (
              <div>
                <h3 className="text-lg font-bold text-slate-900 mb-3">🏷️ الفئات</h3>
                <div className="flex flex-wrap gap-2">
                  {analysis.categories.map((cat, idx) => (
                    <span key={idx} className={`px-4 py-2 rounded-lg font-medium ${colors.badge}`}>
                      {cat}
                    </span>
                  ))}
                </div>
              </div>
            )}
            {analysis.keywords && analysis.keywords.length > 0 && (
              <div>
                <h3 className="text-lg font-bold text-slate-900 mb-3">🔑 الكلمات المفتاحية</h3>
                <div className="flex flex-wrap gap-2">
                  {analysis.keywords.map((keyword, idx) => (
                    <span key={idx} className="px-3 py-1.5 bg-slate-100 text-slate-700 rounded-lg text-sm font-medium border border-slate-200">
                      {keyword}
                    </span>
                  ))}
                </div>
              </div>
            )}
          </div>

          {/* Entités complètes */}
          <div>
            <h3 className="text-lg font-bold text-slate-900 mb-3">👥 الكيانات المستخرجة</h3>
            <div className="grid grid-cols-2 gap-4">
              {analysis.entities?.persons && analysis.entities.persons.length > 0 && (
                <div className="bg-blue-50 p-4 rounded-lg border border-blue-200">
                  <p className="font-medium text-blue-900 mb-2 flex items-center gap-2">
                    <User size={18} />
                    الأشخاص
                  </p>
                  <ul className="space-y-1">
                    {analysis.entities.persons.map((person, idx) => (
                      <li key={idx} className="text-blue-700">• {person}</li>
                    ))}
                  </ul>
                </div>
              )}
              {analysis.entities?.locations && analysis.entities.locations.length > 0 && (
                <div className="bg-green-50 p-4 rounded-lg border border-green-200">
                  <p className="font-medium text-green-900 mb-2 flex items-center gap-2">
                    <MapPin size={18} />
                    الأماكن
                  </p>
                  <ul className="space-y-1">
                    {analysis.entities.locations.map((loc, idx) => (
                      <li key={idx} className="text-green-700">• {loc}</li>
                    ))}
                  </ul>
                </div>
              )}
              {analysis.entities?.organizations && analysis.entities.organizations.length > 0 && (
                <div className="bg-purple-50 p-4 rounded-lg border border-purple-200">
                  <p className="font-medium text-purple-900 mb-2 flex items-center gap-2">
                    <Building size={18} />
                    المؤسسات
                  </p>
                  <ul className="space-y-1">
                    {analysis.entities.organizations.map((org, idx) => (
                      <li key={idx} className="text-purple-700">• {org}</li>
                    ))}
                  </ul>
                </div>
              )}
              {analysis.entities?.dates && analysis.entities.dates.length > 0 && (
                <div className="bg-orange-50 p-4 rounded-lg border border-orange-200">
                  <p className="font-medium text-orange-900 mb-2 flex items-center gap-2">
                    <Calendar size={18} />
                    التواريخ
                  </p>
                  <ul className="space-y-1">
                    {analysis.entities.dates.map((date, idx) => (
                      <li key={idx} className="text-orange-700">• {date}</li>
                    ))}
                  </ul>
                </div>
              )}
            </div>
          </div>

          {/* Métadonnées */}
          <div className="bg-slate-50 p-4 rounded-lg border border-slate-200">
            <h3 className="text-lg font-bold text-slate-900 mb-3">ℹ️ معلومات التحليل</h3>
            <div className="grid grid-cols-2 gap-4 text-sm">
              <div>
                <span className="text-slate-600">طريقة التحليل:</span>
                <span className="font-medium text-slate-900 mr-2">{analysis.analysis_method?.fusion_strategy || 'غير محدد'}</span>
              </div>
              <div>
                <span className="text-slate-600">مزود الذكاء الاصطناعي:</span>
                <span className="font-medium text-slate-900 mr-2">{analysis.metadata?.provider || 'غير محدد'}</span>
              </div>
              <div>
                <span className="text-slate-600">تاريخ التحليل:</span>
                <span className="font-medium text-slate-900 mr-2">
                  {analysis.metadata?.analyzed_at ? new Date(analysis.metadata.analyzed_at).toLocaleString('ar-DZ') : 'غير محدد'}
                </span>
              </div>
              {analysis.analysis_method?.dictionary_keywords_count > 0 && (
                <div>
                  <span className="text-slate-600">كلمات مفتاحية من القاموس:</span>
                  <span className="font-medium text-slate-900 mr-2">{analysis.analysis_method.dictionary_keywords_count}</span>
                </div>
              )}
            </div>
          </div>

          {/* Actions */}
          <div className="flex gap-3 pt-4 border-t border-slate-200">
            {report.pdf_url && (
              <a
                href={report.pdf_url}
                target="_blank"
                rel="noopener noreferrer"
                className="flex-1 px-6 py-3 bg-blue-600 hover:bg-blue-700 text-white rounded-lg font-medium transition-colors flex items-center justify-center gap-2"
              >
                <Download size={20} />
                تحميل PDF
              </a>
            )}
            {report.status === 'pending' && (
              <button
                onClick={() => {
                  onMarkProcessed(report.id);
                  onClose();
                }}
                className="flex-1 px-6 py-3 bg-green-600 hover:bg-green-700 text-white rounded-lg font-medium transition-colors flex items-center justify-center gap-2"
              >
                <Check size={20} />
                تأكيد المعالجة
              </button>
            )}
            <button
              onClick={onClose}
              className="px-6 py-3 bg-slate-200 hover:bg-slate-300 text-slate-700 rounded-lg font-medium transition-colors"
            >
              إغلاق
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

export default DirectorDashboard;