<div align="center">
  <img src="./public/logo.svg" alt="AxieStudio Logo" width="200" height="200">

  # 🎮 AxieStudio User Management System

  [![React](https://img.shields.io/badge/React-18.0+-blue.svg)](https://reactjs.org/)
  [![TypeScript](https://img.shields.io/badge/TypeScript-5.0+-blue.svg)](https://www.typescriptlang.org/)
  [![Supabase](https://img.shields.io/badge/Supabase-Latest-green.svg)](https://supabase.com/)
  [![Stripe](https://img.shields.io/badge/Stripe-Payments-purple.svg)](https://stripe.com/)
  [![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
</div>

---

## 🚀 **Overview**

**AxieStudio User Management System** is a comprehensive, production-ready user management platform that seamlessly integrates user authentication, subscription management, and external application access. Built with modern technologies and enterprise-grade security.

### **🎯 Key Features**

- **🔐 Secure Authentication** - Email confirmation, JWT tokens, row-level security
- **💳 Stripe Integration** - Subscriptions, payments, customer portal
- **⏰ Trial Management** - 7-day trials with accurate countdown timers
- **🎮 AxieStudio Integration** - Auto-account creation and seamless login
- **👤 User Dashboard** - Real-time subscription status and account management
- **🛡️ Admin Panel** - User management, analytics, and system monitoring
- **📱 Responsive Design** - Mobile-first, modern UI with Tailwind CSS

## 🏗️ **Tech Stack**

| Component | Technology | Purpose |
|-----------|------------|---------|
| **Frontend** | React 18 + TypeScript | Modern, type-safe UI |
| **Styling** | Tailwind CSS | Responsive, utility-first design |
| **Backend** | Supabase | Database, auth, real-time features |
| **Functions** | Supabase Edge Functions | Serverless business logic |
| **Payments** | Stripe | Subscription management |
| **External API** | AxieStudio Integration | Seamless app access |

---

## 🚀 **Quick Start**

### **Prerequisites**
- Node.js 18+
- npm or yarn
- Supabase account
- Stripe account
- AxieStudio instance

### **1. Clone Repository**
```bash
git clone https://github.com/axiestudio/UserManagment.git
cd UserManagment
```

### **2. Install Dependencies**
```bash
npm install
# or
yarn install
```

### **3. Environment Setup**
```bash
# Copy environment template
cp .env.example .env

# Edit with your credentials
nano .env
```

### **4. Supabase Setup**
```bash
# Install Supabase CLI
npm install -g supabase

# Login and link project
supabase login
supabase link --project-ref YOUR_PROJECT_REF

# Apply database migrations
supabase db reset

# Deploy Edge Functions
supabase functions deploy
```

### **5. Start Development Server**
```bash
npm run dev
# or
yarn dev
```

🎉 **Your app is now running at `http://localhost:3000`**

---

## 📚 **Documentation**

### **📖 Setup Guides**
- **[🚀 Complete Setup Guide](SUPABASE_SETUP_GUIDE_FOR_NEW_DEVELOPER.md)** - Step-by-step setup for new developers
- **[🗄️ SQL Commands Reference](SQL_COMMANDS_REFERENCE.md)** - Database setup and migrations
- **[⚡ Edge Functions Reference](EDGE_FUNCTIONS_REFERENCE.md)** - All Supabase functions documentation
- **[🔐 Environment Variables](ENVIRONMENT_VARIABLES.md)** - Complete environment configuration

### **🔧 Architecture**
- **Database Schema** - PostgreSQL with RLS policies
- **Authentication** - Supabase Auth with email confirmation
- **Payments** - Stripe subscriptions with webhooks
- **Functions** - 11 Edge Functions for business logic
- **Security** - JWT tokens, CORS, environment secrets

---

## 🎮 **Features Overview**

### **🔐 Authentication & Security**
- ✅ Email confirmation required for signup
- ✅ JWT-based authentication with Supabase
- ✅ Row-level security (RLS) policies
- ✅ Secure password handling
- ✅ Session management

### **💳 Subscription Management**
- ✅ Stripe integration with multiple price tiers
- ✅ 7-day free trials with accurate countdown
- ✅ Subscription upgrades and cancellations
- ✅ Customer portal access
- ✅ Webhook handling for real-time updates

### **🎯 AxieStudio Integration**
- ✅ Automatic account creation in AxieStudio
- ✅ Seamless auto-login functionality
- ✅ Credential management and storage
- ✅ Account synchronization

### **👤 User Experience**
- ✅ Modern, responsive dashboard
- ✅ Real-time trial countdown
- ✅ Subscription status indicators
- ✅ Account management tools
- ✅ Mobile-optimized design

### **🛡️ Admin Features**
- ✅ User management dashboard
- ✅ Subscription analytics
- ✅ System monitoring
- ✅ Database testing tools
- ✅ Function testing interface

---

## 🗂️ **Project Structure**

```
├── src/
│   ├── components/          # Reusable UI components
│   ├── pages/              # Application pages
│   ├── hooks/              # Custom React hooks
│   ├── utils/              # Utility functions
│   └── types/              # TypeScript type definitions
├── supabase/
│   ├── functions/          # Edge Functions (11 functions)
│   └── migrations/         # Database migrations (4 files)
├── public/                 # Static assets
└── docs/                   # Documentation files
```

---

## 🚀 **Deployment**

### **Frontend Deployment**
```bash
# Build for production
npm run build

# Deploy to your hosting platform
# (Vercel, Netlify, etc.)
```

### **Supabase Functions**
```bash
# Deploy all functions
supabase functions deploy

# Deploy specific function
supabase functions deploy function-name
```

### **Environment Variables**
Ensure all production environment variables are set:
- Supabase credentials
- Stripe API keys
- AxieStudio configuration
- Admin user IDs

---

## 🧪 **Testing**

### **Run Tests**
```bash
npm test
```

### **Test Database Connections**
Visit `/test-connections` in your app to verify:
- Database connectivity
- Function deployments
- Migration status
- API integrations

---

## 🤝 **Contributing**

1. **Fork the repository**
2. **Create feature branch** (`git checkout -b feature/amazing-feature`)
3. **Commit changes** (`git commit -m 'Add amazing feature'`)
4. **Push to branch** (`git push origin feature/amazing-feature`)
5. **Open Pull Request**

---

## 📄 **License**

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🆘 **Support**

- **📖 Documentation** - Check our comprehensive guides
- **🐛 Issues** - Report bugs via GitHub Issues
- **💬 Discussions** - Join GitHub Discussions
- **📧 Contact** - Reach out to the development team

---

## 🙏 **Acknowledgments**

- **Supabase** - For the amazing backend-as-a-service platform
- **Stripe** - For robust payment processing
- **React Team** - For the excellent frontend framework
- **Tailwind CSS** - For the utility-first CSS framework

---

<div align="center">
  <p><strong>Built with ❤️ by the AxieStudio Team</strong></p>
  <p>🎮 <em>Empowering creators with seamless user management</em> 🎮</p>
</div>
